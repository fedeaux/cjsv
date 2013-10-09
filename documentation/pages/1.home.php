<h1> CJSV </h1>

<p class="explanation"> <b>C</b>offee/<b>J</b>ava<b>s</b>cript <b>V</b>iew - An html5 template engine. </p>
<p class="explanation"> CJSV is to HTML5 as SASS is to CSS. </p>


<h2> Features </h2>
<ol>
  <li> SASS syntax and CoffeeScript interpolation.
    <pre class="brush: sass">
        a#header.link small[href=+link+] = Follow the +name+
    </pre>
       will become
      <pre class="brush: ruby">
        <a href="+link+" id="header" class="link small">
          Follow the "+name+"
        </a>
      </pre>
  </li>
  
  <li> Indented syntax (Never close an html tag again!)
    <pre class="brush: sass">
        div
          span
            a = Link 1
            a = Link 2
    </pre>
       will become
      <pre class="brush: xml">
        <div>
          <span>
            <a> Link 1 </a>
            <a> Link 2 </a>
          </span>
        </div>
      </pre>
  </li>

  <li>
    Use @ to create a CoffeeScript line, and ## to comment
  </li>

  <li> @ +load will call a view!
    <pre class="brush: sass">
      @ +load menu.sub_item element
    </pre>
    will compile to
    <pre class="brush: ruby">
      _outstream += Views.menu.sub_item element
    </pre>
  </li>

  <li> Transforms a directory hierarchy in an object hierarchy.
    <div>
      <code>cjsv/menu/main.cjsv</code> will be acessible via <code>View.menu.main()</code>
    </div>
  </li>

  <li>
    Use \+ to output a literal plus sign (No CoffeeScript interpolation).
  </li>

</ol>

<h2> Example </h2>
<h3> These input files </h3>
<code> cjsv/menu/main.cjsv </code>
<pre class="brush: sass">
#main
  .menu_item
    a[href=http://www.google.com] = google

</pre>

<code> cjsv/menu/sub.cjsv </code>
<pre class="brush: sass">
(elements)
#sub_menu
  @ for element in elements
    @ +load menu.sub_item element
</pre>

<code> cjsv/menu/sub_item.cjsv </code>
<pre class="brush: sass">
(element)
.sub_menu_item
  a[href=+element.href+] = +element.name+
</pre>

<h3> Will generate </h3>

<pre class="brush: ruby">
@Views =
  menu :
    main : () -&gt;
      _outstream = &quot;
                     &lt;div id=&quot;main&quot;&gt;
                       &lt;div class=&quot;menu_item&quot;&gt;
                         &lt;a href=&quot;http://www.google.com&quot;&gt; google
                         &lt;/a&gt;
                       &lt;/div&gt;
                     &lt;/div&gt;&quot;
      return _outstream

    sub : (elements) -&gt;
      _outstream = &quot;
                     &lt;div id=&quot;sub_menu&quot;&gt;&quot;
      for element in elements
        _outstream += Views.menu.sub_item element
      _outstream += &quot;&lt;/div&gt;&quot;
      return _outstream

    sub_item : (element) -&gt;
      _outstream = &quot;
                     &lt;div class=&quot;sub_menu_item&quot;&gt;
                       &lt;a href=&quot;&quot;+element.href+&quot;&quot;&gt; &quot;+element.name+&quot;
                       &lt;/a&gt;
                     &lt;/div&gt;&quot;
      return _outstream
</pre>

<h3> So you can make </h3>

<pre class="brush: ruby">
  $('#menu').html View.menu.main()
</pre>