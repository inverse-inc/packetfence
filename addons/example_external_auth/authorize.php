<?php
  error_log("Starting authorization");
  foreach ($_POST as $key => $value){
    error_log("Param, $key : $value");
  }
  if (
      isset($_POST["SSID"]) && $_POST["SSID"] == "PF-Test" &&
      isset($_POST["mac"]) && $_POST["mac"] == "00:11:22:33:44:55"
     ) {
    echo json_encode(array("category" => "default", "access_duration" => "1Y"));
  }else{  
    echo json_encode(array("category" => "guest", "access_duration" => "1D"));
  }
