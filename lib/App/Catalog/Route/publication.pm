package App::Catalog::Route::publication;

use App::Catalog::Helper;
use App::Catalog::Controller::Publication;
use Dancer ':syntax';
use Dancer::FileUtils qw/path/;

prefix '/record' => sub {

	get '/new' => sub {
		my $type = params->{type} ||= '';
		
		if($type){
			my $id = new_publication();
			template "backend/forms/$type", {id => $id};
		}
		else {
			template 'add_new';
		}
	};

	# show the record, has user permission to see it?
	get '/edit/:id' => sub {
		my $id = param 'id';
	
		my $record = edit_publication($id);
		if($record){
			$record->{id} = $record->{_id} if $record->{_id} and !$record->{id};
			my $type = $record->{type};
			my $tmpl = "backend/forms/$type";
			template $tmpl, $record;
		}
	};

	post '/update' => sub {
		my $params = params;
		# my $author;
		# my $test;
		# if(ref $params->{author} ne "ARRAY"){
		# 	push @$author, $params->{author};
		# }
		# else{
		# 	$author = $params->{author};
		# }
		# foreach(@{$author}){
		# 	push @$test, from_json($_);
		# }
		# $params->{author} = $test;
		# #return to_dumper $params;
		#if($params->{finalSubmit} and $params->{finalSubmit} eq "recPublish"){
		#	$params->{status} = "public";
		#}
		my $result = update_publication($params);
		#return to_dumper $result;
		
		redirect '/myPUB';
	};

	get '/return/:id' => sub {
		my $id = params->{id};
		my $rec = h->publication->get($id);
		$rec->{status} = "returned";
		try {
			update_publication($rec);
			} catch {
				template "error", {error => "something went wrong"};
			}
		redirect '/myPUB';
	};

	# deleting records, for admins only
	get '/delete/:id' => sub {
		my $id = params->{id};
		
		delete_publication($id);
		redirect '/myPUB';
	};

};

get '/upload' => sub {
	template "backend/upload.tt";
};

post '/upload' => sub {
	my $file = request->upload('file_name');
	my $id = params->{recordId};
	my $path = path(h->config->{upload_dir}, "$id", $file->{filename});
	mkdir h->config->{upload_dir}."/".$id;
	$file->copy_to($path);
	#return to_dumper $file;
};

1;
