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
  $VERSION= "3.40";

sub new {
  my $package = shift;
  return bless({}, $package);
}

sub getMobileArray {
  my %MobileArray;
  my $mobileParam="android,bolt,brew,docomo,foma,hiptop,htc,ipod,ipad,kddi,kindle,lge,maemo,midp,mobi,netfront,nintendo,nokia,novarra,openweb,palm,phone,playstation,psp,samsung,sanyo,softbank,sony,symbian,up.browser,up.link,wap,webos,windows ce,wireless,xv6875.1,mini,mobi,symbos,touchpad,rim,arm,zune,spv,blackberry,mitsu,sie,sama,sch-,moto,ipaq,sec-,sgh-,gradiente,alcat,mot-,sagem,ericsson,lg-,lg/,nec-,philips,panasonic,kwc-,portalm,telit,ericy,zte,hutc,qc-,sharp,vodafone,compal,dbtel,sendo,benq,bird,amoi,becker,lenovo,tsm";
  my @dummyMobileKeys = split(/,/, $mobileParam);
  foreach my $dummy (@dummyMobileKeys) {
      $MobileArray{$dummy}='mobile';
  }
  return %MobileArray;
}
sub getPCArray {
  my %PCArray;
  $PCArray{'msie'}='msie';
  $PCArray{'msie 5'}='msie_5';
  $PCArray{'msie 6'}='msie_6';
  $PCArray{'msie 7'}='msie_7';
  $PCArray{'msie 8'}='msie_8';
  $PCArray{'msie 8'}='msie_9';
  $PCArray{'chrome'}='google_chrome';
  $PCArray{'chrome/0'}='google_chrome_0';
  $PCArray{'chrome/1'}='google_chrome_1';
  $PCArray{'chrome/2'}='google_chrome_2';
  $PCArray{'safari'}='safari';
  $PCArray{'opera'}='opera';
  $PCArray{'konqueror'}='konqueror';
  return %PCArray;
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
    my $deep;
    my $count=0;
    if (@_) {
	    $UserAgent = shift;
	    $deep = shift;
    }
    my $length=length($UserAgent);
    my %ArrayUAparse;
    if (substr($UserAgent,$length-1,1) eq ')') {
     $UserAgent=substr($UserAgent,0,$length-1);
    }
    $UserAgent =~ s/\ /|/g;
    $UserAgent =~ s/\//|/g;
    $UserAgent =~ s/\-/|/g;
    $UserAgent =~ s/\_/|/g;
    my @pairs = split(/\|/, $UserAgent);
    my $deep_to_verify=scalar(@pairs) - $deep - 1;
    my $ind=0;
    my $string="";
    if ($deep > scalar(@pairs)) {
      $deep=scalar(@pairs) - 1;
    }
    foreach my $key (@pairs) {
        if ($ind==0) {
	  $string=$key;
	} else  {
	  $string=$string." ".$key;
	}
	if ($ind > $deep - 1) {
	   $ArrayUAparse{$ind}=$string;
	}
	$ind++;
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
			if ($version) {
			  if (index($version,'.') > -1) {
			    $version =~ s/\.//g;
			  }
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

Site: http://www.apachemobilefilter.org

=head1 AUTHOR

Idel Fuschini (idel.fuschini [at] gmail [dot] com)

=head1 COPYRIGHT

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut