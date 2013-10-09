<?php 

include_once('config.php');
include_once('helpers/pages.php');

class Router {
  function __construct() {
    $this->request = $_SERVER["SERVER_NAME"].$_SERVER["REQUEST_URI"];
    $this->parse_request();
  }

  function get_page() {
    return $this->full_page_path;
  }

  function parse_request() {
    $route = parse_url($this->request);

    $this->path = $route['path'];
    $this->page = get_uri($this->path);

    if($this->page == '') 
      $this->full_page_path = config('pages_dir').config('home');

    else if(!file_exists(config('pages_dir').$this->page)) 
      $this->full_page_path = config('pages_dir').'special/404.php';

    else 
      $this->full_page_path = config('pages_dir').$this->page;
    
  }
}

 ?>