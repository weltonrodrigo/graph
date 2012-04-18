use strict;
use warnings;
use lib qw(lib);

use Text::CSV;
use Getopt::Long;
#use File::Temp;

## o arquivo temporário para a saída do java.
#my  $temp = new File::Temp();
#	$temp->close();
#our $tempfile = $temp->filename;


our $data; 							# O arquivo que contém os dados em formato CSV.
our $jar;
our $iterations = 1;
our $format     = "trademax";
our $dryrun		= 0; 

my $result = GetOptions (
				"d|dados=s" 	   => \$data,
				"j|jar=s"   	   => \$jar,
				"i|iterations=i"   => \$iterations,
				"h|help"		   => \&print_help,
#				"a|arborjs"		   => sub {$format = "arborjs"},
				"n|dry"		   	   => \$dryrun,
			);
sub print_help{
	print qq/
	$0: -d <arquivo.csv> -j <jar file> -i <número de iterações>

	-d	Arquivo CSV no formato: Matrícula, Nome, Origem, Destino, Pontuação
	-j	Arquivo jar do programa TradeMaxizer
	-n	Mostar o arquivo que seria passado ao TradeMaximizer pra processamento.
	-i	Número de iterações do algoritmo [ default 1 ]\n\n/;
	#-a	Imprime no formato do arborjs.org\/halfviz\/ [default: formato do TradeMaximizer]\n\n/;

	exit 0;
}

print_help() and exit 1 unless defined $data and defined $jar;

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

# Formata a saída do programa
sub format{
	my @out = @_;

	print join "\n", @out if $format eq 'trademax';


	if ($format eq 'arborjs'){
		my ($origem, $destino);
		foreach (@out){
			($origem, $destino) = m/^([^)]+)\s+(..\.\d+\.\d+)\s+receives.*(..\.\d+\.\d+)$/;
			
			print "$origem -> $destino\n" if defined $origem and defined $destino;
		}
	}
}

################################
############## main ############
################################

# Criar o índice de pedidos
my %pedidos = index_requests();

# Mostrar a saída que iria pro java.
my $to_java;
if (not $dryrun){
	# Iniciar o processo java
	open $to_java, "| java -jar $jar"
		or die "Could not spawn java proccess: $!\n";
}else{
	$to_java = \*STDOUT;
}

# Cabeçalho
print $to_java "#! EXPLICIT-PRIORITIES ITERATIONS=$iterations\n";

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
