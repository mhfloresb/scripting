#!/usr/bin/perl

# 20150430 - mflores - Backup correos.

# Comandos
$find = "find";
$grep = "grep";
$rm = "rm -rf";
$mkdir = "mkdir";
$cp = "cp";
$mv = "mv";
$touch = "touch";
$chmod = "chmod";

@dirs = ('in', 'out');

foreach $dir (@dirs) {

	# Log
	$log = "/var/log/backup_$dir.log";

	if (! -e $log) {
		system("$touch $log");
	}

	open(LOG,">>$log");

	# Directorios
	$in = "/var/mail/ist.altavoz.net/$dir/new";
	$in_bak = "/var/mail/ist.altavoz.net/$dir/respaldos/";
	$work = "/var/mail/ist.altavoz.net/$dir/new.work/";
	$list = "/var/mail/scripts/list_mails_$dir.txt";

	# Comprobaciones
	if (-e $list) {
		print LOG "Borrando la lista antigua:: $rm $list \n";
		system("$rm $list");
	}

	if (-e $work) {
		print LOG "Borrando el directorio de trabajo antiguo:: $rm $work \n";
		system("$rm $work");
	}

	print LOG "Moviendo el directorio actual al de trabajo:: $mv $in $work \n";
	system("$mv $in $work");

	print LOG "Creando el directorio:: $mkdir $in \n";
	system("$mkdir $in");

	print LOG "Cambiando permisos:: $chmod 777 $in";
	system("$chmod 777 $in");

	# Buscamos los ficheros solo 1 vez y lo guardamos en una lista
	print LOG "$find $work -name '*' > $list \n";
	$find_mails = system("$find $work -name '*' > $list");

	open LIST, $list or die $!;

	while ( my $file = <LIST>) {
		
		open FILE, $file or die $!;
		chomp($file);
		
		# Abrimos el fichero y lo leemos 1 sola vez para saber las direcciones
		# de correo involucradas
		while ( my $line = <FILE>) {
			
			if ( $line =~ m/^To:/ ) {
				
				if ( $line =~ m/([a-z0-9_\-\.]+)\@ist\.cl/) {
					$account = $1;
					
					if (! -e $in_bak.$account) {
						print LOG "$mkdir $in_bak$account \n";
						system("$mkdir $in_bak$account");
					}
					
					print LOG "$cp $file $in_bak$account/ \n";
					system("$cp $file $in_bak$account/");
				}
			}
			
			if ( $line =~ m/^From:/ ) {
				
				if ( $line =~ m/([a-z0-9_\-\.]+)\@ist\.cl/) {
					$account = $1;
					
					if (! -e $in_bak.$account) {
						print LOG "$mkdir $in_bak$account \n";
						system("$mkdir $in_bak$account");
					}
					
					print LOG "$cp $file $in_bak$account/ \n";
					system("$cp $file $in_bak$account/");
				}

			}
			
			if ( $line =~ m/^Cc:/ ) {
				
				if ( $line =~ m/([a-z0-9_\-\.]+)\@ist\.cl/) {
					$account = $1;
					
					if (! -e $in_bak.$account) {
						print LOG "$mkdir $in_bak$account \n";
						system("$mkdir $in_bak$account");
					}
					
					print LOG "$cp $file $in_bak$account/ \n";
					system("$cp $file $in_bak$account/");
				}

			}
			
			if ( $line =~ m/^Reply-to:/ ) {
				
				if ( $line =~ m/([a-z0-9_\-\.]+)\@ist\.cl/) {
					$account = $1;
					
					if (! -e $in_bak.$account) {
						print LOG "$mkdir $in_bak$account \n";
						system("$mkdir $in_bak$account");
					}
					
					print LOG "$cp $file $in_bak$account/ \n";
					system("$cp $file $in_bak$account/");
				}

			}
		}
	}

	print LOG "Borrando el directorio de trabajo:: $rm -rf $work \n";
	system("$rm -rf $work");

	print LOG "Borrando el listado:: $rm -rf $list";
	system("$rm -rf $list");
}

print LOG "Backup terminado!!";

