use inc::Module::Install;

name 'Padre-Plugin-WebGUI';
all_from 'lib/Padre/Plugin/WebGUI.pm';
author 'Patrick Donelan <pat@patspam.com>';
license 'perl';
requires 'WGDev'  => '0.4.0';
test_requires 'Test::More';
recommends 'JSON::XS' => '2.24';

auto_install;

WriteAll;
