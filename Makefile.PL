use strict;
use inc::Module::Install;

name 'Catalyst-View-MicroTemplate';
requires 'Catalyst';
requires 'Moose';
requires 'Text::MicroTemplate::Extended';
requires 'namespace::clean';

WriteAll;