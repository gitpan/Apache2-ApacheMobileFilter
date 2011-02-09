#file:Apache2/AMFCommonLib.pm; 
#-------------------------------- 

#
# Created by Idel Fuschini 
# Date: 01/08/10
# Site: http://www.idelfuschini.it
# Mail: idel.fuschini@gmail.com

package Apache2::AMFCommonLib;
  use strict; 
  use warnings; 
  use vars qw($VERSION);
  use LWP::Simple;
  use IO::Uncompress::Unzip qw(unzip $UnzipError) ;
  use CGI;
  $VERSION= "3.23";

sub new {
  my $package = shift;
  return bless({}, $package);
}


sub Data {
    my $_sec;
	my $_min;
	my $_hour;
	my $_mday;
	my $_day;
	my $_mon;
	my $_year;
	my $_wday;
	my $_yday;
	my $_isdst;
	my $_data;
	($_sec,$_min,$_hour,$_mday,$_mon,$_year,$_wday,$_yday,$_isdst) = localtime(time);
	$_mon=$_mon+1;
	$_year=substr($_year,1);
	$_mon=&correct_number($_mon);
	$_mday=&correct_number($_mday);
	$_hour=&correct_number($_hour);
	$_min=&correct_number($_min);
	$_sec=&correct_number($_sec);
	$_data="$_mday/$_mon/$_year - $_hour:$_min:$_sec";
    return $_data;
}
sub correct_number {
  my ($number) = @_;
  if ($number < 10) {
      $number="0$number";
  } 
  return $number;
}
sub printLog {
	my $self = shift;
	if (@_) {
	    $self->{'printLog'} = shift;
	}
	my $data=Data();
	print "$data - $self->{'printLog'}\n";
} 
sub GetMultipleUa {
  my $self = shift;	
  my $UserAgent;
  if (@_) {
	    $UserAgent = shift;
  }
  my %ArrayPM;
  my $pair;
  my $ind=0;
  my $pairs3;
  my %ArrayUAparse;  
  my @pairs = split(/\ /, $UserAgent);
  foreach $pair (@pairs)
  { 

     if ($ind==0) {
	     if ($pair =~ /\//o) {     	
	     	my @pairs2 = split(/\//, $pair);
    	  	foreach $pairs3 (@pairs2) {
			     if ($ind==0) {
			                if ($pairs3 =~ /\-/o){
				       	     	my @pairs4 = split(/\-/, $pairs3);
				       	     	my $last="";
					    	  	foreach my $pairs5 (@pairs4) {
								     if ($ind==0) {
								       $ind=$ind+1;
								       $ArrayUAparse{$ind}=$pairs5;
							 	     } else {
							 	       $ind=$ind+1;
							    	   $ArrayUAparse{$ind}="$ArrayUAparse{$ind-1}\-$pairs5";
							    	 }
							    	 $last=$pairs5;
					     	 	}
					     	 	my $lengthString=length($last);
					     	 	my $count=0;
					     	 	if ($ind > 1) {
						     	 	$ArrayUAparse{$ind}="$ArrayUAparse{$ind-1}-";
						     	 	while($lengthString > $count) {
							     	 	    my $partString=substr($last,$count,1);
							     	 	    $count=$count+1;
							     	 	    $ind=$ind + 1;
								    	    $ArrayUAparse{$ind}="$ArrayUAparse{$ind-1}$partString";					     	 	    
						     	 	}
					     	 	}
			                } else {
						       $ind=$ind+1;
						       $ArrayUAparse{$ind}=$pairs3;			                
			                }
		 	     } else {
		 	       $ind=$ind+1;
		    	   $ArrayUAparse{$ind}="$ArrayUAparse{$ind-1}\/$pairs3";
		    	 }
     	 	}
     	} else {
	      $ind=$ind+1;
     	  $ArrayUAparse{$ind}="$pair";
     	}
     } else {
        if ($pair =~ /\//o) {
          my $ind2=0;
          my @pairs2 = split(/\//, $pair);
          foreach $pairs3 (@pairs2) {
			     if ($ind2==0) {
			       $ind=$ind+1;
			       $ind2=1;
			       $ArrayUAparse{$ind}="$ArrayUAparse{$ind-1} $pairs3";
		 	     } else {
		 	       $ind=$ind+1;
		    	   $ArrayUAparse{$ind}="$ArrayUAparse{$ind-1}\/$pairs3";
		    	 }             
          }
		} else {
	    	$ind=$ind+1;
     		$ArrayUAparse{$ind}="$ArrayUAparse{$ind-1} $pair";
     	}
     }
  }

  return %ArrayUAparse;

}
sub androidDetection {
	my $self = shift;
	my $ua="";
	if (@_) {
	    $ua = shift;
	}
	my $version='nc';
	my $os='nc';
	if (index($ua,'android') > -1 ) {
	       my $string_to_parse=substr($ua,index($ua,'(') + 1,index($ua,')'));
	       my ($dummy1,$dummy2,$vers,$lan,$dummy5)=split(/\;/,$string_to_parse);
	        if ($lan) {
			my $before=substr($ua,0,index($ua,$lan));
			my $after=substr($ua,index($ua,$lan) + length($lan));
			$ua=$before." xx-xx".$after;
		}
	        if ($vers) {
			my $before=substr($ua,0,index($ua,$vers));
			my $after=substr($ua,index($ua,$vers) + length($vers));
			$vers=substr($vers,index($vers,'android'));
			($os,$version)=split(/ /,$vers);
			if (index($version,'.') > 0) {
			  $version =~ s/\.//g;
			}
			$ua=$before."android xx".$after;
		}
	}
	return ($ua,$version);

}
sub botDetection {
	my $self = shift;
	my $ua="";
	my @arrayBot = ('googlebot','google web preview','msnbot','google.com/bot','ia_archiver','yahoo!','webalta crawler','flickysearchbot','yanga worldsearch','stackrambler','mail.ru','yandex');
	if (@_) {
	    $ua = shift;
	}
	foreach my $pair (@arrayBot) {
	  if (index($ua,$pair) > -1 ) {
	    $ua='It is a bot';
	  }
	}
	return $ua;

}
sub readCookie {
    my $self = shift;
    my $cookie_search;
	if (@_) {
		    $cookie_search = shift;
	}
    my $param_tofound;
    my $string_tofound;
    my $value="";
    my $id_return="";
    my @pairs = split(/;/, $cookie_search);
    my $name;
    foreach $param_tofound (@pairs) {
       ($string_tofound,$value)=split(/=/, $param_tofound);
       if ($string_tofound eq "amf") {
           $id_return=$value;
       }
    }   
    return $id_return;
}
sub readCookie_fullB {
    my $self = shift;
    my $cookie_search;
	if (@_) {
		    $cookie_search = shift;
	}
    my $param_tofound;
    my $string_tofound;
    my $value="";
    my $id_return="";
    my @pairs = split(/;/, $cookie_search);
    my $name;
    foreach $param_tofound (@pairs) {
       ($string_tofound,$value)=split(/=/, $param_tofound);
       if ($string_tofound eq "amfFull") {
           $id_return=$value;
       }
    }   
    return $id_return;
}

sub extValueTag {
   my $self = shift;
   my ($tag,$string);
   if (@_) {
		    $tag = shift;
		    $string = shift;
   }	
   #my ($tag,$string) = @_;
   my $a_tag="\<$tag";
   my $b_tag="\<\/$tag\>";
   my $finish=index($string,"\>") + 1;
   my $x=$finish;
   my $y=index($string,$b_tag);
   my $return_tag=substr($string,$x,$y - $x);  
   return $return_tag;
}
sub printLogInternal {
	my ($info) = @_;
	my $data=Data();
	print "$data - $info\n";
} 
sub GetMultipleUaInternal {
  my ($UserAgent) = @_;	
  my %ArrayPM;
  my $pair;
  my $ind=0;
  my $pairs3;
  my %ArrayUAparse;  
  my @pairs = split(/\ /, $UserAgent);
  foreach $pair (@pairs)
  { 
     if ($ind==0) {
	     if ($pair =~ /\//o) {     	
	     	my @pairs2 = split(/\//, $pair);
    	  	foreach $pairs3 (@pairs2) {
			     if ($ind==0) {
			       $ind=$ind+1;
			       $ArrayUAparse{$ind}=$pairs3;
		 	     } else {
		 	       $ind=$ind+1;
		    	   $ArrayUAparse{$ind}="$ArrayUAparse{$ind-1}\/$pairs3";
		    	 }
     	 	}
     	} else {
	      $ind=$ind+1;
     	  $ArrayUAparse{$ind}="$pair";
     	}
     } else {
        if ($pair =~ /\//o) {
          my $ind2=0;
          my @pairs2 = split(/\//, $pair);
          foreach $pairs3 (@pairs2) {
			     if ($ind2==0) {
			       $ind=$ind+1;
			       $ind2=1;
			       $ArrayUAparse{$ind}="$ArrayUAparse{$ind-1} $pairs3";
		 	     } else {
		 	       $ind=$ind+1;
		    	   $ArrayUAparse{$ind}="$ArrayUAparse{$ind-1}\/$pairs3";
		    	 }             
          }
		} else {
	    	$ind=$ind+1;
     		$ArrayUAparse{$ind}="$ArrayUAparse{$ind-1} $pair";
     	}
     }
  }

  return %ArrayUAparse;

}
sub extValueTagInternal {
   my ($tag,$string) = @_;
   my $a_tag="\<$tag";
   my $b_tag="\<\/$tag\>";
   my $finish=index($string,"\>") + 1;
   my $x=$finish;
   my $y=index($string,$b_tag);
   my $return_tag=substr($string,$x,$y - $x);  
   return $return_tag;
}

=head1 NAME

Apache2::AMFCommonLib - Common Library That AMF uses.

=head1 DESCRIPTION

Is a simple Common Library for AMF

=head1 SEE ALSO

For more details: http://www.idelfuschini.it/apache-mobile-filter-v2x.html

Demo page of the filter: http://www.apachemobilefilter.org

=head1 AUTHOR

Idel Fuschini (idel.fuschini [at] gmail [dot] com)

=head1 COPYRIGHT

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut