[% PROCESS macros.inc -%]
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Configurator - PacketFence</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Configurator for PacketFence">
    <meta name="author" content="Inverse">

    <!-- Le styles -->
    <link href="[% c.uri_for('/static/css/bootstrap.css') %]" rel="stylesheet">
    <link href="[% c.uri_for('/static/app/application.css') %]" rel="stylesheet">
    <link href="[% c.uri_for('/static/css/bootstrap-responsive.css') %]" rel="stylesheet">

    <!-- Le HTML5 shim, for IE6-8 support of HTML5 elements -->
    <!--[if lt IE 9]>
      <script src="[% c.uri_for('/static/app/html5.js') %]"></script>
    <![endif]-->
  </head>

  <body>

    <div class="alert alert-success hide">
      <button class="close" data-dismiss="alert">×</button>
      <strong>Success!</strong> <span></span>
    </div>

    <div class="alert alert-error hide">
      <button class="close" data-dismiss="alert">×</button>
      <strong>Error!</strong> <span></span>
    </div>
