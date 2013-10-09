<h1> Installing and Usage </h1>

<pre class="brush: bash"> git clone https://github.com/ph-everywhere/cjsv any/directory/that/makes/you/happy </pre>

<p> Add this line to your <code>.bashrc</code> or similar. </p>

<pre class="brush: bash">
   alias jw='ruby your/path/to/jsv/jsv.rb --input_dir cjsv/ --output_dir coffee/' 
</pre>

<p> Create your .cjsv files on a cjsv/ folder and make sure that a coffee/ folder exists. </p>

<p> Note that this will generate a .coffee that must be compiled to a .js file </p>