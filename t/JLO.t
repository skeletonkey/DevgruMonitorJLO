#!perl

use strict;
use warnings;

use Test::Deep;
use Test::Exception;
use Test::Mock::Simple;
use Test::More tests => 15;

use Devgru::Monitor;

use_ok( 'Devgru::Monitor::JLO' ) || print "Bail out!\n";

my $resp_mock = Test::Mock::Simple->new(module => 'HTTP::Response');
my $response_obj = HTTP::Response->new();
my $lwp_mock  = Test::Mock::Simple->new(module => 'LWP::UserAgent');
$lwp_mock->add(request => sub { return $response_obj; });

my %args = (
    node_data => {
        'arg1.arg2' => {
            template_vars => [qw(arg1 arg2)],
        },
    },
    type => 'JLO',
    up_frequency => 300,
    down_frequency => 60,
    down_confirm_count => 2,
    version_frequency => 86400,
    severity_thresholds => [ 25 ],
    check_timeout => 5,
    end_point_template => 'http://%s.%s.com/end_point',
);
my $monitor = Devgru::Monitor->new(%args);
my $node = $monitor->get_node('arg1.arg2');

$resp_mock->add(is_success => sub { return 1; });
$resp_mock->add(content    => sub { return q+<html><body><h4>Health Check</h4><ul style="list-style-type: disc"> <li>Hostname: app1.offering.jetson1.coresys.tmcs</li><li>JVM Memory Metrics (MB): <ul style="list-style-type: disc"><li>Used: 414</li><li>Free (Current Av. - Used): 663</li><li>Current Available, 'Xms': 1078</li><li>Max Available, 'Xmx': 3063</li><li>Available processors: 4</li><li>Overall Status: Success</li></ul></li><li>Heartbeat<ul style="list-style-type: disc"> <li>Status: Success</li><li>Status Message: Success</li><li>System Importance: Critical</li></ul></li></ul></body></html>+; });
is($monitor->_check_node('arg1.arg2'), Devgru::Monitor->SERVER_UP, 'Node is up');
is($node->status, Devgru::Monitor->SERVER_UP, 'Node has correct status');
is($node->fail_reason, '', 'Fail reason is blank');
is($node->down_count, 0, 'Down Count is 0');


$resp_mock->add(content    => sub { return q+<html><body><h4>Health Check</h4><ul style="list-style-type: disc"> <li>Hostname: app1.offering.jetson1.coresys.tmcs</li><li>JVM Memory Metrics (MB): <ul style="list-style-type: disc"><li>Used: 414</li><li>Free (Current Av. - Used): 663</li><li>Current Available, 'Xms': 1078</li><li>Max Available, 'Xmx': 3063</li><li>Available processors: 4</li><li>Overall Status: Unsuccessful</li></ul></li><li>Heartbeat<ul style="list-style-type: disc"> <li>Status: Unsuccessful</li><li>Status Message: Something went wrong</li><li>System Importance: Critical</li></ul></li></ul></body></html>+; });
is($monitor->_check_node('arg1.arg2'), Devgru::Monitor->SERVER_UNSTABLE, 'Node is unstable');
is($node->status, Devgru::Monitor->SERVER_UNSTABLE, 'Node has correct status');
is($node->fail_reason, 'Something went wrong', 'Fail reason is correct');
is($node->down_count, 1, 'Down Count is 1');

$resp_mock->add(is_success => sub { return 0;  });
$resp_mock->add(content    => sub { return ''; });
is($monitor->_check_node('arg1.arg2'), Devgru::Monitor->SERVER_DOWN, 'Node is down');
is($node->status, Devgru::Monitor->SERVER_DOWN, 'Node has correct status');
is($node->fail_reason, '', 'Fail reason is blank');
is($node->down_count, 2, 'Down Count is 2');

cmp_deeply([$monitor->version_report], [], 'Empty version report');

throws_ok { $monitor->_check_node() } qr/^No node name provided to _check_node/, 'No node name provided';
