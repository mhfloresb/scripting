#/usr/bin/perl

# 20120625 - mflores - Alerta SMS.

my @celulares=("56912312312");


my $DEBUG=1;
my $host = '127.0.0.1';
my $hostname = `hostname`;
my ($us,$ni,$si,$in,$id)=(0,0,0,0,0);
my ($us_max,$ni_max,$si_max,$in_max)=(60,60,60,30);
my ($us_max_t,$ni_max_t,$si_max_t,$in_max_t)=(3,3,3,3);
my ($us_cur_t,$ni_cur_t,$si_cur_t,$in_cur_t)=(0,0,0,0);
my ($us_on,$ni_on,$si_on,$in_on)=(0,0,0,0);
my $alarm_interval=5;
my $last_alarm=0;
my $ALARM_DATA="/usr/local/statistics/alarm/data.xml";
my $ALARM_CPU_TMP_DATA="/usr/local/statistics/alarm/cpu_data.xml";
my $datos_tmp;
my $alarmas;

use strict;
use IO::Socket;
use XML::Simple;
use SOAP::Lite;

my $subject = "Jhonny";
my $body_cel = "La gente esta loca!";

&send_sms($subject,$body_cel);

sub send_sms () {
    my $mensaje = "AltaVoz: $_[0] $_[1]";
    my $remitente = "AltaVoz";
    my $usuario = "altavoz";
    my $password ="atv895";
    
    my $mensaje_soap = SOAP::Data->name('mensaje')->type('string')->value($mensaje);
    my $remitente_soap = SOAP::Data->name('remitente')->type('string')->value($remitente);
    my $usuario_soap = SOAP::Data->name('usuario')->type('string')->value($usuario);
    my $password_soap = SOAP::Data->name('password')->type('string')->value($password);
    my $soap_response;
    my $destinatario_soap;
    
    my $mensaje_soap = SOAP::Data->name('mensaje')->type('string')->value($mensaje);
    my $remitente_soap = SOAP::Data->name('remitente')->type('string')->value($remitente);
    my $usuario_soap = SOAP::Data->name('usuario')->type('string')->value($usuario);
    my $password_soap = SOAP::Data->name('password')->type('string')->value($password);
    my $soap_response;
    my $destinatario_soap;
    
    foreach (@celulares) {
        $destinatario_soap = SOAP::Data->name('destinatario')->type('string')->value($_);
        $soap_response = SOAP::Lite
            -> uri('http://200.90.201.106/smsWS/')
            -> on_action(sub { join '', @_ })
            -> proxy('http://200.50.123.46/smsws/smsWebService.asmx')
            -> enviaSms($mensaje_soap, $destinatario_soap,$remitente_soap, $usuario_soap, $password_soap);
        
        print $soap_response->paramsout if $DEBUG;
        print $soap_response->result if $DEBUG;
    };
};
