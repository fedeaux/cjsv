#!/usr/bin/env ruby

require 'rubygems'
require 'listen'
require 'fileutils'
require 'optparse'

class JSV
  def initialize()
    @previous_line = ''
    @line = ''
    @stacks = Hash.new()
    @output_stream = ''

    @path = ''

    self.set_initial_state

    @config = {
      'debug' => false,
      'input_dir' => 'cjsv/',
      'output_dir' => 'coffee/',
      'output_filename' => 'jsv.coffee',
      'helpers_filename' => File.dirname(__FILE__)+'/helpers.coffee',
      'output_generated_file' => false,
      'watch_directories' => true,
      'attributes_shorcuts' => {},
      'tags_shorcuts' => {},
      'optmizations' => ['delete_comments', 'shrink_blocks'],
      'object_name' => 'Views'
    }

    OptionParser.new do |opts|
      opts.on("--input_dir [INPUT_DIR]", :text, "Root folder to watch") do |v|
        @config['input_dir'] = v
      end

      opts.on("--output_dir [OUTPUT_DIR]", :text, "Root folder to watch") do |v|
        @config['output_dir'] = v
      end
    end.parse!
    
    @config['output_path'] = @config['output_dir']+@config['output_filename']

    @no_conflict = {
      '\+' => '__JSV_PLUS_SIGN_PLACEHOLDER_4712891294__'
    }

    if File.exist?('.jsv-config.rb') then
      require './.jsv-config.rb'
      puts "using .jsv-config"
      @config.merge!(preferences)
    end

    @self_enclosed_tags = ['img', 'br', 'hr', 'input']
  end

  def preprocess_line()
    @no_conflict.each do |pair|
      @line.gsub! pair[0], pair[1]
    end
  end

  def postprocess_html()
    @no_conflict.each do |pair|
      @parsed_html.gsub! pair[1], pair[0][1..-1]
    end
  end

  def set_initial_state()
    @indentation = {
      'general' => -1,
      'aux_general' => 0,
      'input_coffee' => 0,
      'output_coffee' => 0,
      'curr_html' => 0,
      'last_seen_html' => 0,
      'increased_coffee_on' => []
    }

    @tag_count = {
      'coffee_block' => {0 => 0}
    }

    @func_args = nil
  end

  def _d(str)
    @parsed_html += "##"+str+"\n" if @config['debug']
  end

  def is_there_tags_to_close?()
    @indentation['general'].downto(@indentation['aux_general']) do |i|
      if @stacks[i] != nil and @stacks[i].size > 0 then
        return true
      end
    end
    return false
  end

  def update_coffee_indentation(type=nil)
    _d "gogogo "+type.to_s

    # Close All
    if type == 'close_all' then
      if @tag_count['coffee_block'][@indentation['output_coffee']] == 0 then
        _d "Closed all for "+@line
        _d "no tag opened here!"
        @indentation['output_coffee'] -= 1
      end
      return
    end

    # Close
    if type == 'close' then
      _d "called close"
      return if @tag_count['coffee_block'][@indentation['output_coffee']].nil?

      @tag_count['coffee_block'][@indentation['output_coffee']] -= 1

      if @tag_count['coffee_block'][@indentation['output_coffee']] == 0 then
        _d "close reached 0 with "+@line
        _d "  "+@indentation['increased_coffee_on'].inspect+" "+@indentation['aux_general'].to_s

        # It must only decrease if the current line has a identation larger
        # or equal to the one that generated the block
        if @indentation['increased_coffee_on'].size == 0 or
            @indentation['increased_coffee_on'][-1] >= @indentation['aux_general'] then
          @indentation['output_coffee'] -= 1
          @indentation['increased_coffee_on'].pop
        end
      else
        _d "close decreased "+@indentation['output_coffee'].to_s+" with line "+@line
      end

      @indentation['output_coffee'] = 0 if @indentation['output_coffee'] < 0
      return
    elsif type == 'open' then
      @tag_count['coffee_block'][@indentation['output_coffee']] += 1

      if @config['debug'] or true
        _d "open "+@indentation['output_coffee'].to_s+" ->  "+@tag_count['coffee_block'][@indentation['output_coffee']].to_s
      end

      return
    end

    if self.must_increase_coffee_indentation then
      if @config['debug']
        _d "increased"
      end

      @indentation['increased_coffee_on'] << self.line_identation(@previous_line)
      @indentation['output_coffee'] += 1

      if @tag_count['coffee_block'][@indentation['output_coffee']].nil? then
        @tag_count['coffee_block'][@indentation['output_coffee']] = 0
      end
    elsif type == 'js' or type.nil? then
      #   it must decrease the identation on type = nil only if the last
      # line is JS and there is no tag at this level to close
      if type.nil? then
        if ! self.is_previous_line_js? or self.is_there_tags_to_close? then
          return
        end
        _d "Decreasing with nil type"
      end

      while @indentation['increased_coffee_on'].size > 0 and @indentation['increased_coffee_on'][-1] >= @indentation['aux_general'] do

        if @config['debug']
          _d "decreased"
        end

        @indentation['increased_coffee_on'].pop
        @indentation['output_coffee'] -= 1
        @indentation['input_coffee'] = @indentation['aux_general']
      end
    end

    @indentation['output_coffee'] = 0 if @indentation['output_coffee'] < 0
  end

  def get_helpers_file()
    return @config['helpers_filename']
  end

  def watch?()
    return @config['watch_directories']
  end

  def tag(line)
    line.strip!
    self.tokenize(line)

    html = '<'+@tokens['tag']
    html += ' id="'+@tokens['id'].strip+'"' if @tokens['id'] != nil
    html += ' class="'+@tokens['class'].strip+'"' if @tokens['class'] != nil

    @tokens['attr'].each_pair do |k,v|
      k = 'data'+k if k[0].chr == '-'
      html += ' '+k+'="'+v.gsub('\"', '')+'"'
    end if @tokens['attr'] != nil

    if @self_enclosed_tags.include? @tokens['tag'] then
      @is_self_enclosed_tag = true
      html += '/>'
    else
      @is_self_enclosed_tag = false
      html += '>'
    end

    html += @tokens['text'] if @tokens['text'] != nil

    return @tokens['tag'], html
  end

  def is_js_block_begin(line)
    line.strip == '<?@'
  end

  def is_js_block_end(line)
    line.strip == '?>'
  end

  def is_js(line)
    _line = line.strip
    return (_line[0].chr == '@' or @in_js_block) unless _line == ''
    false
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
      _line .gsub! /^\+load\s*/, '_outstream += '+@config['object_name']+'.'
      @parsed_partial_request = true
    elsif line.include? '+append ' then
      _line .gsub! /^\+append\s*/, '_outstream += '
      @parsed_partial_request = true
    end

    _line
  end

  def is_previous_line_js?()
    self.is_js @previous_line
  end

  def must_increase_coffee_indentation()
    t = /^\s*@\s*(if|while|for|else|unless)(\s|$)/ =~ @previous_line.strip
    return t == 0
  end

  def parse_js_line(line)
    line = (line.gsub('@', '').strip)
    self.parse_partial_request(line)+"\n"
  end

  def is_comment_line? line
    n = line =~ /(\s*)(##)(.*)$/
    return n == 0
  end

  def outstream_line(line, comment = '')
    unless comment.empty?
      comment = '  ##'+comment
    end

    line = _i(@indentation['curr_html'])+line.gsub('"', '\"').gsub('`', '"')+'"'
    _i(@indentation['output_coffee'])+'_outstream += "'+line+comment+"\n"
  end

  def update_html_indentation(force = '')
    if force == '__force_down__' then
      @indentation['curr_html'] -= 1
      @indentation['curr_html'] = 0 if @indentation['curr_html'] < 0
      return
    end

    if @indentation['aux_general'] > @indentation['curr_html'] and
        @indentation['curr_html'] - @indentation['last_seen_html'] <= 1 then
      @indentation['last_seen_html'] = @indentation['curr_html']
      @indentation['curr_html'] += 1
    elsif @indentation['aux_general'] < @indentation['curr_html'] and
        @indentation['curr_html'] - @indentation['last_seen_html'] >= -1 then
      @indentation['last_seen_html'] = @indentation['curr_html']
      @indentation['curr_html'] -= 1
    end
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

        next if line.strip.empty? or is_comment_line? line

        @previous_line = @line unless @line.empty?
        @line = line
        self.preprocess_line

        @indentation['aux_general'] = self.line_identation line

        if(self.is_argline? line ) then #Arguments Line
          @func_args = line.strip.gsub('(', '').gsub(')', '')
            .gsub(' ', '').gsub(',', ', ')
        elsif self.is_js_block_end line then
          @in_js_block = false
        elsif(self.is_js line) then #Embedded JS Line
          puts 'JS Line: '+line if @config['debug']

          @indentation['general'].downto(@indentation['aux_general']) do |i|
            if @stacks[i] != nil and @stacks[i].size > 0 then
              j = i - @indentation['aux_general']
              self.update_html_indentation
              @parsed_html += self.outstream_line('</'+@stacks[i].pop+'>', 'block 01')
              self.update_coffee_indentation 'close'
            end
          end

          self.update_coffee_indentation 'js'

          #Parse coffeescript
          parsed_js_line = self.parse_js_line(line)

          @parsed_html += self.indent_js_line parsed_js_line

          is_single_line_block? line

          html = []
        elsif self.is_js_block_begin line then
          @in_js_block = true
        else #Indented HTML Line
          puts 'HTML Line: '+line if @config['debug']
          self.update_coffee_indentation

          #Closes tags according to the current indentation level
          @indentation['general'].downto(@indentation['aux_general']) do |i|
            if @stacks[i] != nil and @stacks[i].size > 0 then
              self.update_html_indentation
              @parsed_html += self.outstream_line('</'+@stacks[i].pop+'>', 'block 02')
              self.update_coffee_indentation 'close'
            end
          end

          #Parse the tag and generate the html related to this line
          tag, _html = self.tag(line)

          if not @self_enclosed_tags.include? tag then
            @stacks[@indentation['aux_general']] = [] if(not @stacks.has_key?(@indentation['aux_general']))
            @stacks[@indentation['aux_general']].push tag
          end

          self.update_coffee_indentation 'open' unless @is_self_enclosed_tag
          self.update_html_indentation
          @parsed_html += self.outstream_line _html, 'block 03'

          #If is a single line block, must force the generation of output
          if @is_single_line_block then
            html = []
            @is_single_line_block = false
          end

          @indentation['general'] = @indentation['aux_general']
        end
      end

      self.update_coffee_indentation 'close_all'
      @indentation['aux_general'] = 0
      @indentation['general'].downto(0) do |i|
        if @stacks[i] != nil and @stacks[i].size > 0 then
          @parsed_html += self.outstream_line('</'+@stacks[i].pop+'>', 'block 04')
          self.update_coffee_indentation 'close'
          self.update_html_indentation '__force_down__'
        end
      end

      self.postprocess_html
      @parsed_html
    rescue SystemCallError
    end
  end

  def line_identation(line)
    return line.scan(/^\s*/)[0].size/2
  end

  def parse_file(file_name)
    self.set_initial_state

    body = adjust_indentation self.func_body(file_name)
    @func_args = '' if @func_args.nil?
    "#{file_name.split('.').first} : (#{@func_args}) -> \n  _outstream = \"\"\n#{body}return _outstream\n"
  end

  def write_output()
    f = File.new(@config['output_path'], 'w')
    f.puts @output_stream
    f.close
  end

  def parse()
    self.output_line "@"+@config['object_name']+" = \n"
    @path = @config['input_dir']

    Dir.foreach(@path) do |item|
      next if item == '.' or item == '..'

      if File.directory? @path+item then
        self._parse(item)
        @path.gsub!(item+'/', '')

      elsif item.split('.').last == 'cjsv' and not item.include? '#' then
        func = self.parse_file(item)
        self.output_line self.adjust_indentation func
      end
    end

    #Add helper functions
    self.output_line self.adjust_indentation File.open(@config['helpers_filename']).read

    #Make optmizations
    self.optmize

    self.write_output
  end

  def _parse(dir, level=1)
    self.output_line '  '*level+dir+" : \n"
    @path += dir+'/'

    Dir.foreach(@path) do |item|
      next if item == '.' or item == '..'

      if File.directory? @path+item then
        self._parse(item, level+1)
        @path.gsub!(item+'/', '')

      elsif item.split('.').last == 'cjsv' then
        func = self.parse_file(item)
        self.output_line self.adjust_indentation(func, level+1)
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

    if @state == 'text' then
      if @c == '+' then
        @state = 'js'
      end

    elsif ['tag', 'class', 'id', 'none'].include? @state then
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
    if not @config['attributes_shortcuts'].nil? and @config['attributes_shortcuts'].has_key? @current_attribute then
      @current_attribute = @config['attributes_shortcuts'][@current_attribute]
    end
  end

  def values_shortcuts()
    value = @tokens['attr'][@current_attribute]
    if not @config['values_shortcuts'].nil? and @config['values_shortcuts'].has_key? @current_attribute and @config['values_shortcuts'][@current_attribute].has_key? value then
      @tokens['attr'][@current_attribute] = @config['values_shortcuts'][@current_attribute][value]
    end
  end

  def tags_shortcuts()
    if not @config['tags_shortcuts'].nil? and @config['tags_shortcuts'].has_key? @tokens['tag'] then
      @tokens['attr'].merge!(@config['tags_shortcuts'][@tokens['tag']]['attributes'])
      @tokens['tag'] = @config['tags_shortcuts'][@tokens['tag']]['tag']
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

  def optmize()
    if @config['optmizations'].include? 'delete_comments' then
      self.optz_delete_comments
    end

    if @config['optmizations'].include? 'shrink_blocks' then
      self.optz_shrink_blocks
    end
  end

  def is_outsream_line(line)
    (line =~ /^\s*_outstream\s+(\+)?=.*"/) == 0
  end

  def remove_outstream_line(line)
    m = line.match(/^\s+_outstream\s+(\+)?=\s+\"/)[0]
    line.gsub m, ' '*m.size
  end

  def remove_trailing_quote(line)
    line.gsub /(.*)(")(.*)$/, '\1\3'
  end

  def remove_trailing_comment(line)
    line.gsub /(.*)(##)(.*)$/, '\1'
  end

  def optz_shrink_blocks()
    puts "Shrink Blocks"
    prev_line = nil
    write_line = nil
    prev_is_outs = false
    indents = []

    self.get_and_clear_output_stream_lines.each do |line|
      next if line.strip.empty?

      indents.push self.line_identation line

      if self.is_outsream_line(line) then
        if prev_is_outs and indents[-1] == indents[-2] then
          write_line = self.remove_trailing_quote(prev_line)
          prev_line = self.remove_outstream_line(line)
        else
          write_line = prev_line
          prev_line = line
        end

        prev_is_outs = true
      else
        write_line = prev_line
        prev_line = line
        prev_is_outs = false
      end

      self.output_line write_line if !write_line.nil?
    end
  end

  def optz_delete_comments()
    puts "Delete Comments"

    self.get_and_clear_output_stream_lines.each do |line|
      unless is_comment_line? line
         self.output_line remove_trailing_comment line
      end
    end
  end

  def get_and_clear_output_stream_lines()
    aux_output_stream = @output_stream.split "\n"
    @output_stream = ''
    aux_output_stream
  end

  def output_line(line)
    @output_stream += line+"\n"
  end

end

cjsv = JSV.new
cjsv.parse

if cjsv.watch? then
  Listen.to!('.', :filter => /\.cjsv$/) do |modified, added, removed|
    puts Time.now.strftime("%H:%M:%S")
    puts 'changed '+modified.join('/')+'/'+added.join('/')+'/'+removed.join('/')
      
    cjsv = JSV.new
    cjsv.parse
  end
end
