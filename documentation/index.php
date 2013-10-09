<?php 

include('core/template.php');
include('core/router.php');

global $q_template;
global $q_router;

$q_template = new Template();
$q_router = new Router();

$q_template->show_page($q_router->get_page());

?>