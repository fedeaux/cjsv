<?php 

global $q_config;
$q_config = array(
  'home' => '1.home.php',
  'pages_dir' => 'pages/',
  'base_url' => 'http://localhost/docs/cjsv/',
  'site_url' => 'http://localhost/docs/cjsv/index.php/'
);

function config($key) {
  global $q_config;
  return $q_config[$key];
}

 ?>