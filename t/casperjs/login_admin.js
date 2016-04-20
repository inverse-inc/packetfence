var utils = require('utils');
var system = require('system');



var base_url = casper.cli.get('base_url');
var username = casper.cli.get('username');
var password = casper.cli.get('password');
var is_password_valid = casper.cli.get('is_password_valid');

var number_of_tests = 6;

if(is_password_valid) {
    number_of_tests += 2;
} else {
    number_of_tests += 1;
}

casper.test.begin('Packetfence Admin Login Test', number_of_tests, function suite(test) {
    casper.start(base_url + "/admin" , function() {
        test.assertTitle("Administrator - PacketFence");
        test.assertExists('form[name="login"]', "login form is found");
        test.assertExists('#username', "username field found");
        test.assertExists('#password', "password field found");
        test.assertExists('button[type="submit"]', "submit button found");
        this.evaluate(function(username, password) {
            document.querySelector('#username').value = username;
            document.querySelector('#password').value = password;
            document.querySelector('button[type="submit"]').click();
        },username, password);
    });

    // Just wait for a half second for the page to be loaded from the form submit
    casper.waitForSelector("i.icon-user.icon-white", function() {}, function() {}, 500);

    casper.then(function() {
        test.assertTitle("Administrator - PacketFence");
        if(is_password_valid ) {
            test.assertExists("i.icon-user.icon-white", "We are logged in");
            test.assertUrlMatch(/admin\/status/, "We are on the status page");
        } else {
            test.assertExists("div.alert.alert-error");
        }
    });

    casper.run(function() {
        test.done();
    });
});

