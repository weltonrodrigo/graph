#!/usr/bin/perl 
#===============================================================================
#
#         FILE: tradecompare.pl
#
#        USAGE: ./tradecompare.pl  
#
#  DESCRIPTION: Mostra as diferenças entre dois resultados do trademax.
#  				Muito útil para determinar se são os mesmos participantes.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: WELTON RODRIGO TORRES NASCIMENTO (rodrigo@familianascimento.org), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 19-04-2012 13:20:13
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

use File::Temp;

# Infiles
open my $a, "<", shift or die "$0: Erro ao abrir o arquivo: $!";
open my $b, "<", shift or die "$0: Erro ao abrir o arquivo: $!";

# Outfiles
my $a_out = new File::Temp();
my $b_out = new File::Temp();

my @a;
my @b;

while(<$a>){
	s/\s+receives.*$// and push @a, $_;
	last if m/^ITEM SUMMARY/;
}

while(<$b>){
	s/\s+receives.*$// and push @b, $_;
	last if m/^ITEM SUMMARY/;
}

print $a_out $_ foreach sort @a;
print $b_out $_ foreach sort @b;

close $a_out;
close $b_out;

system qw/vim -d/, $a_out->filename, $b_out->filename;
