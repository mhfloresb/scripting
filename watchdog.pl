#!/usr/bin/perl

# ===== Begin Version =========================== #
# 20120624 watchdog.pl Miguel Flores Bustamante
# ===== End Version ============================= #


# ===== Begin Libraries ========================= #
use strict;
# ===== End Libraries =========================== #


# ===== Begin System ============================ #
my $uname = &get_uname();
my $hostname = &get_hostname();
my $pwd = &get_pwd();
# ===== End System ============================== #


# ===== Begin Config ============================ #
my $wd_serv_file = "$pwd/services.cfg";
my $wd_pid_file = "$pwd/watchdog.pid";
my $wd_log_file = "$pwd/wd.log";
my $debug = 1;
# ===== End Config ============================== #


# ===== Begin Binaries ========================== #
my $echo = "/bin/echo";
my $kill = "/bin/kill";
my $rm = "/bin/rm";
my $touch = "/usr/bin/touch";
my $chmod = "/bin/chmod";
# ===== End Binaries ============================ #


# ===== Begin Globals =========================== #
my $wd_pid = "";
my $sms_message = "";
# ===== End Globals ============================= #


# ===== Begin Log =============================== #
if (! -e $wd_log_file) {
	system ("$touch $wd_log_file");
	system ("$chmod 777 $wd_log_file");
}
if (! open( LOG, " >>$wd_log_file")) {
	$sms_message = "Error: No se puede leer el fichero log: $wd_log_file  \n";
	&send_sms($sms_message);
	die "Error: No se puede leer el fichero del log: $wd_log_file \n";
}
else {
	print LOG "OK: Se puede leer el fichero log: $wd_log_file \n";
}
# ===== End Log ================================= #


# ===== Begin WD control ======================== #
if (-e $wd_pid_file) {
	print LOG "Error: Existe el fichero PID: $wd_pid_file \n";
	$sms_message = "Error: Existe el fichero PID: $wd_pid_file  \n";
	&send_sms($sms_message);
}
else {
	print LOG "OK: No existe el fichero PID: $wd_pid_file \n";
	&start_wd();
}
# ===== End WD control ========================== #

if (! -e $wd_serv_file) {
	print LOG "Error: No existe el fichero de servicios: $wd_serv_file \n";
	$sms_message = "Error: Existe el fichero de servicios: $wd_serv_file  \n";
	&send_sms($sms_message);
	
	&kill_wd();
	exit 0;
}

if (! open( SERVICES, $wd_serv_file )) {
	$sms_message = "Error: No se puede leer el fichero de servicios: $wd_serv_file  \n";
	&send_sms($sms_message);
	die "Error: No se puede leer el fichero de servicios: $wd_serv_file \n";
}
else {
	print LOG "OK: Se puede leer el fichero PID $wd_pid_file \n";
}

while (<SERVICES>) {
	next if ( $_ =~ /^\#/ );
	next if ( $_ =~ /^\s*$/ );
	print LOG "OK: $_";
	chomp($_);
	
	(my $name, my $pid_file, my $restart) = split(/::/,$_);
	
	if (! -e $pid_file) {
		print LOG "Error: No existe el fichero: $pid_file, reiniciando el proceso \n";
		$sms_message = "Error: No existe el fichero: $pid_file, reiniciando el proceso \n";
		&send_sms($sms_message);
		
		&restart_proc($restart);
		next;
	}
	
	if (! open (PID, $pid_file)) { 
		print LOG "Error: No se puede leer el fichero del pid: $pid_file \n";
		$sms_message = "Error: No se puede leer el fichero del pid: $pid_file \n";
		&send_sms($sms_message);
		
		&restart_proc($restart);
		next;
	}
	
	my $pid = <PID>;
	chomp $pid;
	
	my $ret = `ps -p $pid -o comm=`;
	if ($ret != $name) {
		print LOG "Error: Proceso no grepeado, reiniciando el proceso: $name \n";
		$sms_message = "Error: Proceso no grepeado, reiniciando el proceso: $name  \n";
		&send_sms($sms_message);
		
		&restart_proc($restart);
		next;
	}
	
	close (PID);
}

close (SERVICES);
print LOG "OK: Eliminando el pid_file \n";
print LOG "OK: .................... FIN \n";
close (LOG);
&rm_controls();

# ===== Begin Subroutines ======================= #
sub get_uname() {
	my $uname = `/bin/uname`;
	chomp($uname);
	
	return $uname;
}

sub get_hostname() {
	my $hostname = `/bin/hostname`;
	chomp($hostname);
	
	return $hostname;
}

sub get_pwd() {
	my $pwd = `/bin/pwd`;
	chomp($pwd);
	
	return $pwd;
}

sub get_pid() {
	open( WDPID, $wd_pid_file) || die "Error: No se puede leer el fichero del pid $_ $!\n";
	my $wd_pid = <WDPID>;
	chomp $wd_pid;
	
	return $wd_pid;
}

sub kill_wd() {
	print LOG "Matando el WD pid $wd_pid \n";
	system("$kill -9 $wd_pid");
}

sub rm_controls() {
	print LOG "Eliminando el fichero $wd_pid_file \n";
	system("$rm $wd_pid_file");
}

sub start_wd() {
	print LOG "OK: Iniciando WD pid $wd_pid_file";
	system("$echo $$ > $wd_pid_file");
}

sub restart_proc() {
	system("$_[0]");
	print LOG "OK: Reiniciando el proceso: $_[0] \n";
}

sub send_sms() {
	print LOG "OK: Enviando Correo ... $_";
}
# ===== End Subroutines ========================= #
