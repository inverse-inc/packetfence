<?php
  error_log("Starting authentication");
  foreach ($_POST as $key => $value){
    error_log("Param, $key : $value");
  }
  if (
      isset($_POST["username"]) && $_POST["username"] == "testing" &&
      isset($_POST["password"]) && $_POST["password"] == "123"
     ) {
    echo json_encode(array("result" => 1, "message" => "Valid username and password"));
  }else{  
    echo json_encode(array("result" => 0, "message" => "Invalid username and password"));
  }
