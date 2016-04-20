var utils = require('utils');
var system = require('system');



var base_url = casper.cli.get('base_url');
var username = casper.cli.get('username');
var password = casper.cli.get('password');

var number_of_tests = 9;

casper.test.begin('Packetfence Admin Logout Test', number_of_tests, function suite(test) {
    casper.start(base_url + "/admin" , function() {
        test.assertTitle("Administrator - PacketFence");
        test.assertExists('form[name="login"]', "login form is found");
        test.assertExists('#username', "username field found");
        test.assertExists('#password', "password field found");
        test.assertExists('button[type="submit"]', "submit button found");
        this.fill('form[name="login"]', {
            username: username,
            password: username,
        },true);
    });

    // Just wait for a half second for the page to be loaded from the form submit
    casper.waitForSelector("i.icon-user.icon-white", function() {}, function() {}, 500);

    casper.then(function() {
        test.assertTitle("Administrator - PacketFence");
        test.assertExists("i.icon-user.icon-white");
    });

    casper.thenOpen(base_url + "/admin/logout", function() {
    });

    casper.then(function() {
        test.assertTitle("Administrator - PacketFence");
        test.assertDoesntExist("i.icon-user.icon-white");
    });

    casper.run(function() {
        test.done();
    });
});

