        <div id="footer">
          <?php 
          if(file_exists('pages/special/footer.php')) {
            include('pages/special/footer.php');
          }
          ?>    
          <script type="text/javascript">

    function path()
    {
      var args = arguments,
      result = [];
      
      for(var i = 0; i < args.length; i++)
        result.push(args[i].replace('@', '<?php echo config('base_url') ?>plugins/syntax_highlighter/scripts/'));
      
      return result
    };
    
    SyntaxHighlighter.autoloader.apply(null, path(
      'bash shell             @shBrushBash.js',
      'css                    @shBrushCss.js',
      'xml                    @shBrushXml.js',
      'java                   @shBrushJava.js',
      'js jscript javascript  @shBrushJScript.js',
      'php                    @shBrushPhp.js',
      'text plain             @shBrushPlain.js',
      'py python              @shBrushPython.js',
      'ruby rails ror rb      @shBrushRuby.js',
      'sass scss              @shBrushSass.js',
      'sql                    @shBrushSql.js'
    ));

    SyntaxHighlighter.all();

          </script>
        </div>
      </div> <!-- #content -->
    </div>
  </body>
</html>
