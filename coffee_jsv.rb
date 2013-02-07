#!/usr/bin/env ruby

require 'rubygems'
require 'listen'

class CJSV
  def initialize()
    @previous_line = ''
    @line = ''
    @stacks = Hash.new()
    @indentation = {
      'html' => -1,
      'aux_html' => 0,
      'input_coffee' => 0,
      'output_coffee' => -1
    }
    @path = ''
    # @debug = true

    @opts = {
      'debug' => false,
      'input_dir' => 'cjsv/',
      'output_dir' => 'coffee/',
      'output_filename' => 'jsv.coffee',
      'helpers_filename' => File.dirname(__FILE__)+'/coffee_jsv_helpers.coffee',
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

  def get_helpers_file()
    return @opts['helpers_filename']
  end

  def watch?()
    return @opts['watch_directories']
  end

  def tag(line)
    line.strip!
    self.tokenize(line)

    #html = '  '*@_indentation_level+
    html = '<'+@tokens['tag']
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

    #html += "\n"+'  '*(@_indentation_level + 1)+@tokens['text'] if @tokens['text'] != nil
    html += @tokens['text'] if @tokens['text'] != nil

    return @tokens['tag'], html
  end

  def is_js(line)
    line.strip[0].chr == '@'
  end

  def is_argline?(line)
    _line = line.strip
    return _line[0].chr+_line[-1].chr == '()'
  end

  def is_single_line_block?(line)
    @is_single_line_block = ((line =~ /if|while|for|else|unless/i).is_a? Numeric and not (line.include? '{'))
  end

  def parse_partial_request(line)
    _line = line
    if line.include? '+load ' then
      _line .gsub! /^\+load\s*/, '_outstream += JSV.'
      @parsed_partial_request = true
    end
    _line
  end

  def must_increase_coffee_indentation()
    t = /^\s*@\s*(if|while|for|else|unless)/ =~ @previous_line.strip
    return t == 0
  end

  def parse_js_line(line)
    line = (line.gsub('@', '').strip)
    self.parse_partial_request(line)+"\n"
  end

  def is_comment_line? line
    return line.strip[0..1] == '//'
  end

  def outstream_line(line)
    _i(@indentation['output_coffee'])+'_outstream += "'+line.gsub('"', '\"').gsub('`', '"')+'"'+"\n"
  end

  def update_coffee_indentation(force = '')
    if force == '__force_down__' then
      @indentation['output_coffee'] -= 1
      @indentation['output_coffee'] = 0 if @indentation['output_coffee'] < 0
      return
    end

    if self.must_increase_coffee_indentation then
      @indentation['output_coffee'] += 1
      @indentation['input_coffee'] = @indentation['aux_html']
    elsif @indentation['input_coffee'] > @indentation['aux_html'] then
      @indentation['output_coffee'] -= 1
      @indentation['input_coffee'] = @indentation['aux_html']
    end

    @indentation['output_coffee'] = 0 if @indentation['output_coffee'] < 0
  end

  def _i(level, char = ' ')
    level = 0 if level < 0
    return char*level*2
  end

  def indent_js_line parsed_line
    self._i(@indentation['output_coffee'])+parsed_line
  end

  def func_body(file_name)
    html = []
    @parsed_html = ''

    begin
      File.foreach(@path+file_name) do |line|
        #There are four types of line: Arguments Line, Embedded JS Line, Comments Line and Indented HTML Line
        @previous_line = @line unless @line.empty?
        @line = line
        puts @previous_line, "["+self.must_increase_coffee_indentation.to_s+"]" if /666/ =~ @line

        next if line.strip.empty? or is_comment_line? line
        @indentation['aux_html'] = self.line_identation line

        if(self.is_argline? line ) then #Arguments Line
          @func_args = line.strip.gsub('(', '').gsub(')', '')
            .gsub(' ', '').gsub(',', ', ')

        elsif(self.is_js line) then #Embedded JS Line
          puts 'JS Line: '+line if @opts['debug']

          @indentation['html'].downto(@indentation['aux_html']) do |i|
            if @stacks[i] != nil and @stacks[i].size > 0 then
              j = i - @indentation['aux_html']
              @parsed_html += self.outstream_line('</'+@stacks[i].pop+'> # block 01')
              self.update_coffee_indentation
            end
          end

          #Parse coffeescript
          parsed_js_line = self.parse_js_line(line)

          @parsed_html += self.indent_js_line parsed_js_line

          is_single_line_block? line

          html = []
        else #Indented HTML Line
          puts 'HTML Line: '+line if @opts['debug']

          #Closes tags according to the current indentation level
          @indentation['html'].downto(@indentation['aux_html']) do |i|
            if @stacks[i] != nil and @stacks[i].size > 0 then
              j = i - @indentation['aux_html']
              @parsed_html += self.outstream_line('</'+@stacks[i].pop+'> # block 02')
              self.update_coffee_indentation
            end
          end

          #Parse the tag and generate the html related to this line
          tag, _html = self.tag(line)

          if not @self_enclosed_tags.include? tag then
            @stacks[@indentation['aux_html']] = [] if(not @stacks.has_key?(@indentation['aux_html']))
            @stacks[@indentation['aux_html']].push tag
          end

          puts @previous_line, "["+self.must_increase_coffee_indentation.to_s+"]" if /666/ =~ @line

          self.update_coffee_indentation
          @parsed_html += self.outstream_line _html+" # block 03 "+_html

          #If is a single line block, must force the generation of output
          if @is_single_line_block then
            html = []
            @is_single_line_block = false
          end

          @indentation['html'] = @indentation['aux_html']
        end
      end

      @indentation['html'].downto(0) do |i|
        if @stacks[i] != nil and @stacks[i].size > 0 then
          self.update_coffee_indentation '__force_down__'
          @parsed_html += self.outstream_line('</'+@stacks[i].pop+'>  # block 04')
        end
      end

      @parsed_html
    rescue SystemCallError
    end
  end

  def line_identation(line)
    return line.scan(/^\s*/)[0].size/2
  end

  def parse_file(file_name)
    @indentation['output_coffee'] = -1

    body = adjust_indentation self.func_body(file_name)
    @func_args = '' if @func_args.nil?
    "#{file_name.split('.').first} : (#{@func_args}) -> \n  _outstream = ''\n#{body}"
  end

  def parse()
    @f = File.new(@opts['output_path'], 'w')

    @f.puts "@JSV = \n"
    @path = @opts['input_dir']

    Dir.foreach(@path) do |item|
      next if item == '.' or item == '..'

      if File.directory? @path+item then
        self._parse(item)
        @path.gsub!(item+'/', '')

      elsif item.split('.').last == 'cjsv' and not item.include? '#' then
        func = self.parse_file(item)
        @f.puts self.adjust_indentation func
      end
    end

    #Add helper functions
    @f.puts self.adjust_indentation File.open(@opts['helpers_filename']).read
    @f.close

    puts File.open(@opts['output_path'], 'r').read if(@opts['output_generated_file'])
  end

  def _parse(dir, level=1)
    @f.puts '  '*level+dir+" : \n"
    @path += dir+'/'

    Dir.foreach(@path) do |item|
      next if item == '.' or item == '..'

      if File.directory? @path+item then
        self._parse(item, level+1)
        @path.gsub!(item+'/', '')

      elsif item.split('.').last == 'cjsv' then
        func = self.parse_file(item)
        @f.puts self.adjust_indentation(func, level+1)
      end
    end
  end

  def adjust_indentation(code_block, level=1)
    ind = '  '*level
    ind+code_block.gsub(/\n/m, "\n"+ind)
    #code_block
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

cjsv = CJSV.new()
cjsv.parse()

if cjsv.watch? then
  Listen.to('.', :filter => /\.cjsv$/) do |modified, added, removed|
    puts Time.now.strftime("%H:%M:%S")
    puts 'changed '+modified.join('/')+'/'+added.join('/')+'/'+removed.join('/')
    cjsv.parse()
  end
end