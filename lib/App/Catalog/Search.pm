package App::Catalog::Search;

get '/search' => sub {
	my $q = params->{'q'};
	my $hits = h->bag->search(cql_query => $q);
	template 'backend/list', $hits;
};

1;