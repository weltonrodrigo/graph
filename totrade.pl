use strict;
use warnings;

use Text::CSV;

sub read_data{
		
	my $csv = new Text::CSV({binary => 1});
		
	open my $fh, "<", "c:/users/rodrigo/graph/normalizada.csv" or die $!;
	
	# discard first.
	$csv->getline($fh); 
	
	#my $i = 0;
	#my $limit = 100;
	
	my $data;
	while (my $row = $csv->getline($fh)){
		push @$data, $row;
		#return $data if $i++ eq $limit;
	}
	
	return $data;
}

sub sort_by_points {
	#ordenar por ordem descrescente de pontos e depois por ordem alfabética
    $b->{points} <=> $a->{points} || $a->{name} cmp $b->{name};
}

# Each user will be a vertice.
# Will give each user a numeric id
# Will also group users by Source.
sub index_users {
    my %users;
    my $i = 0;
    foreach my $entry ( @{ read_data() } ) {
        my ( $dst, $name, $src, $points ) = @$entry;

        unless ( grep { defined $_->{$name} } @{ $users{$src} } ) {
            my $user = {
                id     => $i++,
                name   => $name,
                src    => $src,
                dst    => $dst,
                points => $points
            };

            # Save this user object on the appropriate slot.
            push @{ $users{$src} }, $user;

        }
    }

    return \%users;
}

sub list_of_destinations{
    my ($users, $dst) = @_;
    my @out;
    
    foreach my $user_in_dst (@{ $users->{$dst} }){
        # só incluir o usuário na saída se o lugar pra onde ele quer ir
        # tiver alguém querendo sair (não for um array vazio).
        push @out, $user_in_dst if @{ $users->{ $user_in_dst->{dst}} };
    }
    
    return sort sort_by_points @out;   
}

################################
################################
################################
my $jar = 'C:\users\rodrigo\graph-copy\trademaximizer-1.3a\tm.jar';

open my $to_trademax, "| java -jar $jar"
		or die "Could not spaw java: $!\n";
		
# Cabeçalho do arquivo
print $to_trademax "#!EXPLICIT-PRIORITIES\n";

my $users = index_users();
foreach my $source ( sort keys %{$users} ) {
USER:
    foreach my $user ( @{ $users->{$source} } ) {
        
 		# Só incluir este usuário no trade se houver pelo menos um 
		# usuário no destino.
		my @destinations = list_of_destinations( $users, $user->{dst} );
		
		next USER unless @destinations;
		
        my $out =
          sprintf( "(%s) %s.%s :", $user->{name}, $user->{src} , $user->{id} );
          
		foreach (@destinations){
		    
		    #$out .=  qq/ $_->{name}.$_->{src}/;
		    $out .=  qq/ $_->{src}.$_->{id}:$_->{points}/;
		}

		print $to_trademax "$out\n";
    }

}
