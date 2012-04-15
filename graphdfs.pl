use strict;
use warnings;
use Graph::Easy;
use Graph::Directed;
use Text::CSV;
use Data::Dumper;
use Color::Mix;
use Graph::Traversal::DFS;

no warnings 'recursion';


my $fs = "->";
$|++;


my $edges_as_names = read_data();

# Will use numbers as vertices. So, need a map to remember.
my @vertices;
my %nome;
my %seen;
my $i = 0;
foreach my $edge (@$edges_as_names){
	my ($src, $dst) = @$edge;
	$vertices[$i] = $src and $nome{$src} = $i++ unless $seen{$src}++;
	$vertices[$i] = $dst and $nome{$dst} = $i++ unless $seen{$dst}++;
}

# Now, translate all edges as numbers, using the map.
my @edges_as_numbers = map { [ $nome{$_->[0]}, $nome{$_->[1]} ] } @$edges_as_names;

my $g = new Graph::Directed( ( countedged => 0, edges => \@edges_as_numbers ) );
my @Cycles;
my ($begin, $end) = (0,$#vertices);
foreach my $vertice ($begin..$end) {
		
		my $visited = [];
		my $path    = [];
		dfs($vertice, my $start = $vertice, $visited, $path);	
}
print "São ". ( $#Cycles + 1 ). " ciclos.\n";
sub read_data{
	
	my $csv = new Text::CSV({binary => 1});
		
	open my $fh, "<", "c:/users/rodrigo/graph/normalizada.csv" or die $!;
	
	# discard first.
	$csv->getline($fh); 
	
	#my $i = 0;
	#my $limit = 100;
	
	my $data;
	while (my $row = $csv->getline($fh)){
		
		push @$data, [ $row->[2], $row->[0], $row->[1] ];
		#return $data if $i++ eq $limit;
		
		}
		
	return $data;
}

sub print_path {
		my ($path) = @_;
		
		print join $fs, @$path;
}

sub dfs{
		my ($node, $Start, $Visited, $path) = @_;
		
		#print $vertices[$node];
		
		if ($$Visited[$node]){
			if ($node == $Start){
				push @$path, $vertices[$node];
				print sprintf ("%02d", $#$path) . " ";
				print_path($path);
				#print "\t\t-> Cycle.\n";
				print "\n";
				push @Cycles, [@$path];
				pop @$path;
			} else{
				#print "\t\t-> Seen.\n";
			}
		} else{
			push @$path, $vertices[$node];
			#push $path, $node;
			$$Visited[$node] = 1;
			foreach my $successor ($g->successors($node)){
				#print $fs;
				dfs($successor, $Start, $Visited, $path);
			}
			pop @$path;
			#print "\t\t-> End.\n";
		}
		#print_path($path);		
}

sub find_biggest_cycle{
	my $g = shift;
	
		my $dfs = sub dfs{
		my ($node, $Start, $visited, $path) = @_;
		
		#print $vertices[$node];
		
		if ($$visited[$node]){
			if ($node == $Start){
				push @$path, $vertices[$node];
				print sprintf ("%02d", $#$path) . " ";
				print_path($path);
				#print "\t\t-> Cycle.\n";
				print "\n";
				push @Cycles, [@$path];
				pop @$path;
			} else{
				#print "\t\t-> Seen.\n";
			}
		} else{
			push @$path, $vertices[$node];
			#push $path, $node;
			$$visited[$node] = 1;
			foreach my $successor ($g->successors($node)){
				#print $fs;
				dfs($successor, $Start, $Visited, $path);
			}
			pop @$path;
			#print "\t\t-> End.\n";
		}
		#print_path($path);		
}
	
	foreach ($g->vertices){
		my $visited = [];
		my $path    = [];
		dfs($_, $_, $visited, $path);	
			}
	}