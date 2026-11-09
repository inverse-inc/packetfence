<?php
  error_log("Starting authentication");
  // The source sends the fields as a form (default) or as a JSON object
  $params = $_POST;
  if (isset($_SERVER["CONTENT_TYPE"]) && stripos($_SERVER["CONTENT_TYPE"], "application/json") === 0) {
    $params = json_decode(file_get_contents("php://input"), true);
    if (!is_array($params)) {
      $params = array();
    }
  }
  foreach ($params as $key => $value){
    error_log("Param, $key : " . (is_array($value) ? json_encode($value) : $value));
  }
  if (
      isset($params["username"]) && $params["username"] === "testing" &&
      isset($params["password"]) && $params["password"] === "123"
     ) {
    echo json_encode(array("result" => 1, "message" => "Valid username and password"));
  }else{  
    echo json_encode(array("result" => 0, "message" => "Invalid username and password"));
  }
