use strict;
use warnings;
use lib qw(lib);

use Text::CSV;
use Getopt::Long;

our $data; 							# O arquivo que contém os dados em formato CSV.
our $jar;
our $iterations = 1;
our $format     = "trademax";
our $dryrun		= 0; 
our $prioridade = 'explicit';

my $result = GetOptions (
				"d|dados=s" 	   => \$data,
				"j|jar=s"   	   => \$jar,
				"i|iterations=i"   => \$iterations,
				"h|help"		   => \&print_help,
#				"a|arborjs"		   => sub {$format = "arborjs"},
				"n|dry"		   	   => \$dryrun,
				"p|prioridade=s"   => \$prioridade, 
			);
sub print_help{
	print qq/
	$0: -d <arquivo.csv> -j <jar file> -i <número de iterações>

	-d	Arquivo CSV no formato: Matrícula, Nome, Origem, Destino, Pontuação
	-j	Arquivo jar do programa TradeMaxizer
	-n	Mostar o arquivo que seria passado ao TradeMaximizer pra processamento.
	-i	Número de iterações do algoritmo [ default 1 ]
	-p	O tipo de prioridade a ser utilizado [default explicit]
	/, "\n\n";
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

# A prioridade é dada pela pontuação, sendo desempatados pela
# idade (mais velho ganha).
#
# No caso desta função, o desempate é pelo inverso da ordem alfabética
# por falta de dados.
sub sort_by_points {
	$a->{points} <=> $b->{points} || $b->{name} cmp $a->{name};
}

# Os usários solicitantes serão indexados por origem.
sub index_requests {
    my %pedidos;
	my @requisicoes = read_data();

    foreach my $entry ( @requisicoes ) {
        my ( $mat, $name, $src, $dst, $points ) = @$entry;


		# Nova entrada no índice
		my $pedido;
        if ( not defined $pedidos{$src}{$mat} ) {
            $pedido = {
                mat    => $mat,
                name   => $name,
                src    => $src,
                dst    => $dst,
                points => $points
            };
        }
        else {

            warn "$0: Usuário duplicado no arquivo de dados: "
              . "$mat $name $src $dst $points\n";

			next;
        }

		# Salva este pedido na origem apropriada.
		$pedidos{$src}{$mat} = $pedido;
	}

    return %pedidos;
}

# Lista todos as vagas num destino num ordem aleatória.
sub vagas{
    my ($pedidos, $dst) = @_;
    my @vagas;

    foreach my $matricula ( keys %{ $pedidos->{$dst} } ){
		my $guarda_saindo = $pedidos->{$dst}{$matricula}; 
		my $seu_destino   = $guarda_saindo->{dst};

		# Tem inscrito pra sair lá?
		my $inscritos = $pedidos->{ $seu_destino };
		next unless keys %{ $inscritos };

        push @vagas, $guarda_saindo;
    }
	return @vagas;

}

# Organizar prioridades
# Colocar as vagas pela ordem crescente de prioridade
sub priorizar_vagas {
    my @vagas = @_;

    # Primeiro coloca na ordem crescente de pontos e alfa-
    # bética invertida.
    @vagas = sort sort_by_points @vagas;

    # A prioridade inicial é o número de pontos.
    foreach my $v (@vagas) {
        $v->{prioridade} = $v->{points} unless defined $v->{prioridade};
    }

    for ( my $i = 0 ; $i < $#vagas ; $i++ ) {
        my $a = $vagas[$i];
        my $b = $vagas[ $i + 1 ];

        # Em caso de empate, ajuste a prioridade do
        # vencedor.
        if ( $b->{prioridade} <= $a->{prioridade} ) {
            $b->{prioridade} = $a->{prioridade} + 1;
        }

    }

	return @vagas;
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
my   $cabecalho = "#! ";
my   @options;
push @options, "EXPLICIT-PRIORITIES" if $prioridade eq 'explicit';
push @options, "ITERATIONS=$iterations";

print $to_java $cabecalho . ( join " ", @options ) . "\n";

# Imprimir as entradas no formato do programa
# (nome) Origem.Matricula.Pontuacao: Vaga.Matricula.pontuação=pontuação ...
#
foreach my $origem ( keys %pedidos ) {
USER:
    foreach my $matricula ( keys %{ $pedidos{$origem} } ) {
		my $pedido = $pedidos{$origem}{$matricula};

        my $out = sprintf "(%s) %s.%d.%s: ",
          $pedido->{name},
          $pedido->{src},
          $pedido->{mat},
          $pedido->{points};
        
		# Obter lista de vagas.
		my @vagas = vagas( \%pedidos, $pedido->{dst} );

        foreach my $vaga ( priorizar_vagas(@vagas) ) {

            $out .= sprintf "%s.%d.%d=%d ",
              $vaga->{src}, $vaga->{mat}, $vaga->{points},
              $vaga->{prioridade}
				if $prioridade eq 'explicit';

            $out .= sprintf "%s.%d.%d ",
              $vaga->{src}, $vaga->{mat}, $vaga->{points}
				if $prioridade eq 'none';


        }

		print $to_java "$out\n";
    }

}
