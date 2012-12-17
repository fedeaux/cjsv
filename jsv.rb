#!/Users/fedorius/.rvm/rubies/ruby-1.9.3-p0/bin/ruby

require 'rubygems'
require 'listen'

class JSV
  def initialize()
    @stacks = Hash.new()
    @indentation_level = -1
    @path = ''

    @opts = {
      'debug' => false,
      'input_dir' => 'js/_jsv/',
      'output_dir' => 'js/',
      'output_filename' => 'jsv.js',
      'output_generated_file' => false,
      'watch_directories' => true,
      'attributes_shorcuts' => {},
      'tags_shorcuts' => {}
    }

    @opts['output_path'] = @opts['output_dir']+@opts['output_filename']

    if File.exist?('.jsv-config.rb') then
      require './.jsv-config.rb'
      puts "using .jsv-config"
      @opts.merge!(preferences)
    end

    @self_enclosed_tags = ['img', 'br', 'hr', 'input']
  end

  def watch?()
    return @opts['watch_directories']
  end

  def tag(line)
    line.strip!
    self.tokenize(line)

    html = '  '*@_indentation_level+'<'+@tokens['tag']
    html += ' id="'+@tokens['id'].strip+'"' if @tokens['id'] != nil
    html += ' class="'+@tokens['class'].strip+'"' if @tokens['class'] != nil

    @tokens['attr'].each_pair do |k,v|
      k = 'data'+k if k[0].chr == '-'
      html += ' '+k+'="'+v.gsub('\"', '')+'"'
    end if @tokens['attr'] != nil

    if @self_enclosed_tags.include? @tokens['tag'] then
      html += '/>'
    else
      html += '>'
    end

    html += "\\\n"+'  '*(@_indentation_level + 1)+@tokens['text'] if @tokens['text'] != nil

    return @tokens['tag'], html
  end

  def is_js(line)
    line.strip[0].chr == '@'
  end

  def outstream_block(html)
    _html = "\\\n"+html.join("\\\n").gsub('"', '\"').gsub('`', '"')

    return '_outstream += "'+_html+'";'+"\n" if ! _html.empty?
    return ''
  end

  def is_argline?(line)
    _line = line.strip
    return _line[0].chr+_line[-1].chr == '()'
  end

  def is_single_line_block?(line)
    @is_single_line_block = ((line =~ /if|while|for/i).is_a? Numeric and not (line.include? '{'))
  end

  def parse_partial_request(line)
    line .gsub /^\+load\s*/, '_outstream += JSV.'
  end

  def parse_js_line(line)
    line = (line.gsub('@', '').strip)
    
    self.parse_partial_request(line)+"\n"
  end

  def is_comment_line? line
    return line.strip[0..1] == '//'
  end

  def func_body(file_name)
    html = []
    parsed_html = ''

    begin
      File.foreach(@path+file_name) do |line|
        #There are four types of line: Arguments Line, Embedded JS Line, Comments Line and Indented HTML Line

        next if line.strip.empty? or is_comment_line? line
        @_indentation_level = self.line_identation line


        if(self.is_argline? line ) then #Arguments Line
          @func_args = line.strip.gsub('(', '').gsub(')', '').gsub(' ', '').gsub(',', ', ')

        elsif(self.is_js line) then #Embedded JS Line
          puts 'JS Line: '+line if @opts['debug']

          @indentation_level.downto(@_indentation_level) do |i|
            html.push '  '*i+'</'+@stacks[i].pop+'>' if @stacks[i] != nil and @stacks[i].size > 0
          end
          
          parsed_html += self.outstream_block(html) if(html.size > 0)
          parsed_html += '  '*self.line_identation(line) + self.parse_js_line(line)

          is_single_line_block? line

          html = []
        else #Indented HTML Line
          puts 'HTML Line: '+line if @opts['debug']

          #Closes tags according to the current indentation level
          @indentation_level.downto(@_indentation_level) do |i|
            html.push '  '*i+'</'+@stacks[i].pop+'>' if @stacks[i] != nil and @stacks[i].size > 0
          end

          #Parse the tag and generate the html related to this line
          tag, _html = self.tag(line)

          if not @self_enclosed_tags.include? tag then
            @stacks[@_indentation_level] = [] if(not @stacks.has_key?(@_indentation_level))
            @stacks[@_indentation_level].push tag
          end
          
          html.push _html

          #If is a single line block, must force the generation of output
          if @is_single_line_block then
            parsed_html += self.outstream_block(html)
            html = []
            @is_single_line_block = false
          end

          @indentation_level = @_indentation_level
        end
      end
      
      @indentation_level.downto(0) do |i|
        html.push '  '*i+'</'+@stacks[i].pop+'>' if @stacks[i] != nil and @stacks[i].size > 0
      end
      
      parsed_html += self.outstream_block(html)
    rescue SystemCallError
    end
  end
  
  def line_identation(line)
    return line.scan(/^\s*/)[0].size/2
  end
  
  def parse_file(file_name)
    body = self.func_body(file_name)
    @func_args = '' if @func_args.nil?
    "#{file_name.split('.').first} : function(#{@func_args}) {\n  var _outstream='';\n  #{body}  return _outstream;\n},"
  end

  def parse()
    @f = File.new(@opts['output_path'], 'w')

    @f.puts "var JSV = {\n"
    @path = @opts['input_dir']

    Dir.foreach(@path) do |item|
      next if item == '.' or item == '..'

      if File.directory? @path+item then
        self._parse(item)
        @path.gsub!(item+'/', '')

      elsif item.split('.').last == 'jsv' and item.include? '#' == false then
        func = self.parse_file(item)
        @f.puts func
      end
    end

    @f.puts "}"
    @f.close
   
    puts File.open(@opts['output_path'], 'r').read if(@opts['output_generated_file'])
  end

  def _parse(dir)
    @f.puts dir+" : {\n"
    @path += dir+'/'

    Dir.foreach(@path) do |item|
      next if item == '.' or item == '..'

      if File.directory? @path+item then
        self._parse(item)
        @path.gsub!(item+'/', '')

      elsif item.split('.').last == 'jsv' then
        func = self.parse_file(item)
        @f.puts func
      end
    end

    @f.puts "},"
  end

  def set_next_state()
    _last_state = @state

    # states = tag, class, id, text, attr_name, attr_value, js
    if ['tag', 'class', 'id', 'none', 'text'].include? @state then
      if @c == '#' then
        @state = 'id'
      elsif @c == '.' then
        @state = 'class'
      elsif @c == '=' then
        @state = 'text' #must be terminal state
      elsif @c == '+' then
        @state = 'js'
      elsif @c == '[' then
        @state = 'attr_name'
      end

    elsif ['js'].include? @state then
      if @c == '+' then
        @state = @last_state
      end

    elsif ['attr_name', 'attr_value'].include? @state then
      if @c == '=' then
        @state = 'attr_value'
      elsif @c == '+' then
        @state = 'js'
      elsif @c == ']' then
        @state = 'none'
      end
    end

    if @state != _last_state then
      @last_state = _last_state
      return true
    end

    return false
  end

  def attributes_shortcuts()
    if not @opts['attributes_shortcuts'].nil? and @opts['attributes_shortcuts'].has_key? @current_attribute then
      @current_attribute = @opts['attributes_shortcuts'][@current_attribute]
    end
  end

  def values_shortcuts()
    value = @tokens['attr'][@current_attribute]
    if not @opts['values_shortcuts'].nil? and @opts['values_shortcuts'].has_key? @current_attribute and @opts['values_shortcuts'][@current_attribute].has_key? value then
      @tokens['attr'][@current_attribute] = @opts['values_shortcuts'][@current_attribute][value]
    end
  end

  def tags_shortcuts()
    if not @opts['tags_shortcuts'].nil? and @opts['tags_shortcuts'].has_key? @tokens['tag'] then
      @tokens['attr'].merge!(@opts['tags_shortcuts'][@tokens['tag']]['attributes'])
      @tokens['tag'] = @opts['tags_shortcuts'][@tokens['tag']]['tag']
    end
  end

  def state_changed()
    if @tokens[@state] == nil and ! ['attr_name', 'attr_value'].include? @state then
      @tokens[@state] = ''
    end

    #Check for tags shortcuts
    if @last_state == 'tag' then
      self.tags_shortcuts()
    end

    if @last_state == 'attr_value'
      self.values_shortcuts()
    end

    if @state == 'attr_name' then
      @current_attribute = ''
    elsif @state == 'attr_value' or (@state == 'none' and @last_state == 'attr_name') then
      #Check for attributes_shortcuts
      self.attributes_shortcuts()
      @tokens['attr'][@current_attribute] = '' if @tokens['attr'][@current_attribute] == nil
    end

    self.append_js()
  end

  def tokenize(line)
    @state = 'tag'
    @last_state = ''
    @current_attribute = ''

    @tokens = { 'tag' => 'div',
                'attr' => {}}

    line.split('').each do |c|
      @c = c
      if self.set_next_state then #state changed        
        self.state_changed
      else
        #check tag state
        @tokens['tag'] = '' if @state == 'tag' and @tokens['tag'] == 'div'

        if @state == 'attr_name' then
          @current_attribute += c
        elsif @state == 'attr_value' then
          @tokens['attr'][@current_attribute] += c
        else
          @tokens[@state] += c
        end
      end
    end

    @c = nil
    self.append_js()
    @tokens
  end

  def append_js()
    return if @last_state != 'js' or @tokens['js'] == ''

    _js = '`+'+@tokens['js']+'+`'

    if @state == 'attr_name' then
      @current_attribute += _js
    elsif @state == 'attr_value' then
      @tokens['attr'][@current_attribute] += _js
    else
      @tokens[@state] += _js
    end
    
    @tokens['js'] = ''
  end
end

jsv = JSV.new()
jsv.parse()

if jsv.watch? then
  Listen.to('.', :filter => /\.jsv$/) do |modified, added, removed|
    puts Time.now.strftime("%H:%M:%S")
    puts 'changed '+modified.join('/')+'/'+added.join('/')+'/'+removed.join('/')
    jsv.parse()
  end
end
