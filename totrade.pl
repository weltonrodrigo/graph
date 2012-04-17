use strict;
use warnings;
use lib qw(lib);

use Text::CSV;
use Getopt::Long;

# O arquivo que contém os dados em formato CSV.
our $data;
our $jar;

my $result = GetOptions (
				"d|dados=s" => \$data,
				"j|jar=s"   => \$jar
			);

die "$0: Informe o arquivo de dados com -d <arquivo.csv>\n"
	unless defined $data;

die "$0: Informe a localização do jar do TradeMaximizer com -j <tm.jar>\n"
	unless defined $jar;

sub read_data{
		
	my $csv = new Text::CSV({binary => 1});
		
	open my $fh, "<", "$data" or die $!;
	
	# discard first.
	$csv->getline($fh); 
	
	my @data;
	while (my $row = $csv->getline($fh)){
		push @data, $row;
	}
	
	return @data;
}

sub sort_by_points {
	#ordenar por ordem crescente de pontos e depois por ordem alfabética
    $a->{points} <=> $b->{points} || $a->{name} cmp $b->{name};
	#	or die "$0: Dois usuários com a mesma pontuação:"
	#		   . join "\n", $a->{name}, $a->{mat}, $a->{points}
	#		   . join "\n", $b->{name}, $b->{mat}, $b->{points}
	#		   . "\n";
}

# Os usários solicitantes serão indexados por origem.
sub index_requests {
    my %pedidos;
	my @requisicoes = read_data();

    foreach my $entry ( @requisicoes ) {
        my ( $mat, $name, $src, $dst, $points ) = @$entry;

		# Inicializa o array da origem e destino se já não existir.
		$pedidos{$src} = [] unless ref $pedidos{$src};
		$pedidos{$dst} = [] unless ref $pedidos{$dst};

		die "$0: Usuário duplicado no arquivo de dados: $mat $name $src $dst $points\n"
			if grep { defined $_->{$mat} } @{ $pedidos{$src} };

		my $pedido = {
			mat    => $mat,
			name   => $name,
			src    => $src,
			dst    => $dst,
			points => $points
		};

		# Salva este pedido na origem apropriada.
		push @{ $pedidos{$src} }, $pedido;

	}

    return %pedidos;
}

# Lista todos as vagas num destino ordenadas por prioridade.
sub vagas_no_destino{
    my ($pedidos, $dst) = @_;
    my @vagas;
    
    foreach my $guarda_que_deseja_sair ( @{ $pedidos->{$dst} } ){

		# Só incluir nas vagas possíveis aquelas que também podem ser atendidas,
		# ou seja, cujo destino também tem alguém querendo sair.
        push @vagas, $guarda_que_deseja_sair if @{ $pedidos->{ $guarda_que_deseja_sair->{dst} } };
    }
    
    return sort sort_by_points @vagas;   
}

################################
############## main ############
################################

# Criar o índice de pedidos
my %pedidos = index_requests();

# Iniciar o processo java
open my $to_java, "| java -jar $jar"
		or die "Could not spawn java proccess: $!\n";
		
# Cabeçalho
print $to_java "#! EXPLICIT-PRIORITIES ITERATIONS=1000\n";

# Imprimir as entradas no formato do programa
# (nome) Origem.Matricula.Pontuacao: Vaga.Matricula:pontuação Vaga.Matricula:pontuação
#
foreach my $source ( keys %pedidos ) {
USER:
    foreach my $pedido ( @{ $pedidos{$source} } ) {
        
		my @vagas = vagas_no_destino( \%pedidos, $pedido->{dst} );
		
		next USER unless @vagas;
		
        my $out = qq/($pedido->{name}) $pedido->{src}.$pedido->{mat}.$pedido->{points}:/;
          
		$out .=  qq/ $_->{src}.$_->{mat}.$_->{points}=$_->{points}/ foreach (@vagas);

		print $to_java "$out\n";
    }

}
