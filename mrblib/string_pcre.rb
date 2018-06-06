class String
  alias_method :old_index, :index
  def index(pat, offs=0)
    return old_index(pat, offs) unless pat.is_a? Regexp
    if offs < 0
      offs += self.size
      return nil if offs < 0
    end
    m = pat.match(self, offs)
    m ? m.begin(0) : nil
  end

  alias_method :old_sub, :sub
  def sub(*args, &blk)
    if args[0].class == String
      return blk ? old_sub(*args) { |x| blk.call(x) } : old_sub(*args)
    end

    m = args[0].match(self)
    return self if !m || m.size == 0
    r = ''
    r += m.pre_match
    if blk
      s = blk.call(m[0])
    else
      s = args[1]._replace_back_reference(m)
    end
    r += s
    r += m.post_match
    r
  end

  alias_method :old_gsub, :gsub
  def gsub(*args, &blk)
    if args[0] == nil or args[0].class.to_s == 'String'
      return blk ? old_gsub(*args) { |x| blk.call(x) } : old_gsub(*args)
    end

    r = ""
    i = 0
    while i <= length
      m = args[0].match(self[i..-1])
      break if !m || m.size == 0

      r += m.pre_match
      if blk
        s = blk.call(m[0])
      else
        s = args[1]._replace_back_reference(m)
      end
      r += s

      if i == length
        break
      elsif m.end(0) > 0
        i += m.end(0)
      else
        r += self[i]
        i += 1
      end
    end
    r += self[i..-1]
    r
  end

  def =~(a)
    begin
      (a.class.to_s == 'String' ? Regexp.new(a.to_s) : a) =~ self
    rescue
      false
    end
  end

  alias_method :old_split, :split
  def split(*args, &blk)
    return [] if self.empty?

    if args[0].nil? or args[0].class.to_s == 'String'
      return blk ? old_split(*args) { |x| blk.call(x) } : old_split(*args)
    end

    if args.size < 2
      limited = false
      limit = 0
    else
      limit = args[1].to_i

      if limit > 0
        return [self.dup] if limit == 1
        limited = true
      else
        tail_empty = true
        limited = false
      end
    end

    pattern = args[0]
    result = []
    # case '//'
    if pattern.source.empty?
      index = 0
      while true
        break if limited and limit - result.size <= 1
        break if index + 1 >= self.length

        result << self[index]
        index += 1
      end
      result << self[index..-1]
    else
      start = 0
      last_match = nil
      last_match_end = 0

      while m = pattern.match(self, start)
        break if limited and limit - result.size <= 1

        unless m[0].empty? and (m.begin(0) == last_match_end)
          result << m.pre_match[last_match_end..-1]
          result.push(*m.captures)
        end
        
        if m[0].empty?
          start += 1
        elsif last_match and last_match[0].empty?
          start = m.end(0) + 1
        else
          start = m.end(0)
        end

        last_match = m
        last_match_end = m.end(0) || 0

        break if self.length <= start 
      end

      if last_match
        result << last_match.post_match
      elsif result.empty?
        result << self.dup
      end
    end

    # Trim (not specified in the second argument)
    if !result.empty? and (limit.nil? || limit == 0)
      while result.last.nil? or result.last.empty?
        result.pop
      end
    end

    result
  end

  alias_method :old_slice, :slice
  alias_method :old_square_brancket, :[]

  def [](*args)
    return old_square_brancket(*args) unless args[0].class == Regexp

    if args.size == 2
      match = args[0].match(self)
      if match
        if args[1] == 0
          str = match[0]
        else
          str = match.captures[args[1] - 1]
        end
        return str
      end
    end

    match_data = args[0].match(self)
    if match_data
      result = match_data.to_s
      return result
    end
  end

  alias_method :slice, :[]
  alias_method :old_slice!, :slice!
  def slice!(*args)
    return old_slice!(*args) unless args[0].class == Regexp

    result = slice(*args)
    lm = Regexp.last_match
    self[*args] = '' if result
    Regexp.last_match = lm
    result
  end

  # private
  def _replace_back_reference(match)
    result = ""
    index = 0
    while index < self.length
      current = index
      while current < self.length && self[current] != '\\'
        current += 1
      end
      result += self[index, (current - index)]
      break if current == self.length

      if current == self.length - 1
        result += '\\'
        break
      end
      index = current + 1

      cap = self[index]

      case cap
      when "&"
        result += match[0]
      when "`"
        result += match.pre_match
      when "'"
        result += match.post_match
      when "+"
        result += match.captures.compact[-1].to_s
      when /[0-9]/
        result += match[cap.to_i].to_s
      when '\\'
        result += '\\'
      else
        result += '\\' + cap
      end
      index += 1
    end
    result
  end

  alias_method :old_scan, :scan
  def scan(*args, &blk)
    return old_scan(*args) if args[0].class == String

    i = 0
    ret = []
    while m = args[0].match(self, i)
      break if !m || m.size == 0
      return ret if m.end(0) == i

      val = (m.size == 1 ? m[0] : m.captures)
      i = m.end(0)

      if blk
        blk.call(val)
      else
        ret << val
      end
    end

    ret
  end


  #
  # XXX: Need pull-request to http://github.com/mruby/mruby mrbgems/mruby-string-ext
  #
  def []=(*args)
    index = args[0]
    if args.size != 3
      val = args[1]
      count = nil   
    else
      count = args[1]
      val = args[2]
    end

    case index
    when Fixnum
      index += self.size if index < 0

      raise IndexError, "index #{index} out of string" if index < 0 or index > self.size
      raise IndexError, "unable to find charactor at: #{index}" unless bi = index

      if count
        count = count.to_i
        raise IndexError, "count is negative" if count < 0

        total = index + count
        bs = total - bi
      else
        bs = index == size ? 0 : (index + 1) - bi
      end

      splice bi, bs, val
    when String
      raise IndexError, "string not matched" unless start = self.index(index)

      splice start, index.size, val
    when Range
      start = index.first.to_i
      start += self.size if start < 0

      raise RangeError, "#{index.first} is out of range" unless bi = start
      stop = index.last.to_i
      stop += self.size if stop < 0
      stop -= 1 if index.exclude_end?

      if stop < start
        bs = 0
      else
        bs =  stop + 1 - bi
      end

      splice bi, bs, val
    when Regexp
      count = count || 0

      if match = index.match(self)
        ms = match.size
      else
        raise IndexError, "regexp does not match"
      end

      count += ms if count < 0 and -count < ms
      raise IndexError, "index #{count} out of match bounds" unless count < ms and count >= 0

      bi = match.begin(count)
      bs = match.end(count) - bi

      splice bi, bs, val
    else
      index = index.to_i

      if count
        return self[index, count] = val
      else
        return self[index] = val
      end
    end

    return val
  end

  def splice(start , count, val)
    self.replace(self[0...start] + val + self[(start + count)..-1].to_s)
  end
end
