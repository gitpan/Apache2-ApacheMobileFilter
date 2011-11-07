#file:Apache2/AMFSwitcher.pm; 
#-------------------------------- 

#
# Created by Idel Fuschini 
# Date: 01/08/10
# Site: http://www.idelfuschini.it
# Mail: idel.fuschini@gmail.com



package Apache2::AMFSwitcher; 
  
  use strict; 
  use warnings; 
  use Apache2::AMFCommonLib ();
  
  use Apache2::RequestRec ();
  use Apache2::RequestUtil ();
  use Apache2::SubRequest ();
  use Apache2::Log;
  use Apache2::Filter (); 
  use APR::Table (); 
  use LWP::Simple;
  use Apache2::Const -compile => qw(OK REDIRECT DECLINED);
  use IO::Uncompress::Unzip qw(unzip $UnzipError) ;
  use constant BUFF_LEN => 1024;
  use vars qw($VERSION);
  $VERSION= "3.40a";
  #
  # Define the global environment
  #
  my $CommonLib = new Apache2::AMFCommonLib ();
  my $mobileversionurl="none";
  my $fullbrowserurl="none";
  my $redirecttranscoderurl="none";
  my $redirecttranscoder="false";
  my $wildcardredirect="false";
  my $mobileversionurl_ck="/";
  my $fullbrowserurl_ck="/";
  my $redirecttranscoderurl_ck="/";
  my @IncludeString;
  my @ExcludeString;
  my $mobilenable="false";
  my $mobileDomain="none";
  my $fullbrowserDomain="none";
  my $transcoderDomain="none";
  my $forcetablet="false";
  
  my %ArrayPath;
  $ArrayPath{1}='none';
  $ArrayPath{2}='none';
  $ArrayPath{3}='none';
  $CommonLib->printLog("---------------------------------------------------------------------------"); 
  $CommonLib->printLog("AMFSwitcher Version $VERSION");
  if ($ENV{AMFMobileHome}) {
  } else {
	  $CommonLib->printLog("AMFMobileHome not exist.	Please set the variable AMFMobileHome into httpd.conf");
	  $CommonLib->printLog("Pre-Requisite: WURFLFilter must be activated");
	  ModPerl::Util::exit();
  }
  $CommonLib->printLog("If you use AMFWURFLFilter is better to use WebPatch LoadWebPatch not exist.");
  $CommonLib->printLog("Pre-Requisite: WURFLFilter must be activated");	 	
   &loadConfigFile();
sub loadConfigFile {
	my $null="";
	my $null2="";
	my $null3="";
	my $val;
	my $capability;
	my $r_id;
	my $dummy;
	$CommonLib->printLog("AMFSwitcher: Start read configuration from httpd.conf");
	if ($ENV{FullBrowserUrl}) {
		$fullbrowserurl=$ENV{FullBrowserUrl};
		$ArrayPath{2}=$ENV{FullBrowserUrl};
		$CommonLib->printLog("FullBrowserUrl is: $fullbrowserurl");
		$fullbrowserurl_ck=$ENV{FullBrowserUrl};
		if (substr ($fullbrowserurl,0,5) eq "http:") {
			my ($dummy,$dummy2,$url_domain,$dummy3)=split(/\//, $fullbrowserurl);
			$fullbrowserDomain=$url_domain;
			
		}
	}		
	if ($ENV{RedirectTranscoderUrl}) {
		$redirecttranscoderurl=$ENV{RedirectTranscoderUrl};
		$ArrayPath{3}=$ENV{RedirectTranscoderUrl};
		$redirecttranscoder="true";
		$redirecttranscoderurl_ck=$ENV{RedirectTranscoderUrl};
		$CommonLib->printLog("RedirectTranscoderUrl is: $redirecttranscoderurl");		
		if (substr ($redirecttranscoderurl,0,5) eq "http:") {
			my ($dummy,$dummy2,$url_domain,$dummy3)=split(/\//, $redirecttranscoderurl);
			$transcoderDomain=$url_domain;
			
		}
	}
	if ($ENV{"AMFSwitcherExclude"}){
		@ExcludeString=split(/,/, $ENV{AMFSwitcherExclude});
		$CommonLib->printLog("SwitcherExclude is: $ENV{AMFSwitcherExclude}");						
	}
	if ($ENV{WildCardRedirect}) {
		if ($ENV{WildCardRedirect} eq 'true') {
			$wildcardredirect="true";
		} else {
			$wildcardredirect="false";
		}
		$CommonLib->printLog("WildCardRedirect is: $wildcardredirect");		
	}
	if ($ENV{ForceTabletAsFullBrowser}) {
		if ($ENV{ForceTabletAsFullBrowser} eq 'true') {
			$forcetablet="true";
		} else {
			$forcetablet="false";
		}
		$CommonLib->printLog("ForceTabletAsFullBrowser is: $forcetablet");		
	}
	if ($ENV{MobileVersionUrl}) {
		$mobileversionurl=$ENV{MobileVersionUrl};
		$ArrayPath{1}=$ENV{MobileVersionUrl};
		$CommonLib->printLog("MobileVersionUrl is: $mobileversionurl");
		$mobileversionurl_ck=$ENV{MobileVersionUrl};
		push(@ExcludeString,$ENV{MobileVersionUrl});
		if (substr ($mobileversionurl,0,5) eq "http:") {
			my ($dummy,$dummy2,$url_domain,$dummy3)=split(/\//, $mobileversionurl);
			$mobileDomain=$url_domain;
			
		}
	}
	if ($ENV{FullBrowserMobileAccessKey}) {
		$mobilenable="$ENV{FullBrowserMobileAccessKey}";
		$CommonLib->printLog("FullBrowserMobileAccessKey is: $ENV{FullBrowserMobileAccessKey}");
		$CommonLib->printLog("For access the device to fullbrowser set the link: <url>?$mobilenable");
	}
	$CommonLib->printLog("Finish loading  parameter");
}
sub handler    {
    my $f = shift;
    my $capability2;
    my $query_string=$f->args;
    my $device_claims_web_support="null";
    my $is_wireless_device="null";
    my $is_transcoder="null";
    my $location="none";
    my $return_value=Apache2::Const::DECLINED;
    my $device_type=1;
    my $no_redirect=1;
    my $uri=$f->unparsed_uri();
    my $servername=$f->get_server_name();
    my $uriAppend="";
    my $filter="true";
    my %ArrayQuery;
    my $isTablet="null";
    my $amf_device_ismobile = "true";

    if ($query_string) {
	my @vars = split(/&/, $query_string); 	  
	foreach my $var (sort @vars){
		if ($var) {
			my ($v,$i) = split(/=/, $var);
			$v =~ tr/+/ /;
			$v =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
			if ($i) {
				$i =~ tr/+/ /;
				$i =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
				$i =~ s/<!--(.|\n)*-->//g;
			}
			$ArrayQuery{$v}="ok";
			}
	}
    }
    my $cookie = $f->headers_in->{Cookie} || '';
    my $amfFull=$CommonLib->readCookie_fullB($cookie);
    if ($ArrayQuery{$mobilenable}) {
	$f->err_headers_out->set('Set-Cookie' => "amfFull=false; path=/;");
	$amfFull="ok";
    }
    if ($f->pnotes('is_tablet')) {      
    	$isTablet=$f->pnotes('is_tablet')
    }
    if ($f->pnotes('is_transcoder')) {
    	$is_transcoder=$f->pnotes('is_transcoder');
    }
    if ($f->pnotes('amf_device_ismobile')) {
    	$amf_device_ismobile=$f->pnotes('amf_device_ismobile');
    }
    foreach my $string (@ExcludeString) {
        if (index($uri,$string) > -1) {
           $filter="false";
        } 
    }
    if ($filter eq "true"){
		if ($amf_device_ismobile eq 'false'|| ($isTablet eq "true" && $forcetablet eq "true")) {
			if ($fullbrowserDomain ne $servername) {
				if ($fullbrowserurl ne 'none') {
					if ($wildcardredirect eq 'true'){
					$location=$uri;
						if ($location =~ /$mobileversionurl_ck/o) { 
					$location =~ s/$mobileversionurl_ck/$fullbrowserurl/;
						} else {
					$location = $fullbrowserurl;            
				    }
					} else {
						$location = $fullbrowserurl;            
					}
				} 
				$device_type=2;
			}
		} else {
			if ($mobileDomain ne $servername) {
				if ($wildcardredirect eq 'true'){
					$location=$uri;
					if ($location =~ /$fullbrowserurl_ck/o) { 
						$location =~ s/$fullbrowserurl_ck/$mobileversionurl/;
					} else {
						$location = $mobileversionurl;            
					}
			} else {
		            	$location = $mobileversionurl;            
			}
				$device_type=1;
			}
		}
	    if ($is_transcoder eq 'true') {
			if ($transcoderDomain ne $servername) {
				if ($redirecttranscoderurl ne 'none') {
					if ($wildcardredirect eq 'true'){
					$location=$uri;
						if ($location =~ /$fullbrowserurl_ck/o) { 
					$location =~ s/$fullbrowserurl_ck/$redirecttranscoderurl/;
						} else {
					$location = $redirecttranscoderurl;            
				    }
					}
				}
				$device_type=3;
			}
	    }

	    if ($ArrayPath{$device_type} eq substr($uri,0,length($ArrayPath{$device_type}))) {
	    	$no_redirect=0;
	    }
		if ($location ne "none" && $amfFull eq "") {
			    if (substr ($location,0,5) eq "http:") { 
					$f->headers_out->set(Location => $location);
					$f->status(Apache2::Const::REDIRECT); 
					$return_value=Apache2::Const::REDIRECT;
			    } else {
			        if ($no_redirect==1) {
						$f->headers_out->set(Location => $location);
						$f->status(Apache2::Const::REDIRECT); 
						$return_value=Apache2::Const::REDIRECT;		        
			        }
			    }
		} 
	    
    }
	return $return_value;
} 

  1; 
=head1 NAME

Apache2::AMFSwitcher - Used to switch the device to the apropriate content (mobile, fullbrowser or for transcoder)


=head1 DESCRIPTION

This module has the scope to manage with WURFLFilter.pm module the group of device (MobileDevice, PC and transcoder).

To work AMFSwitcher has need WURFLFilter configured.

For more details: http://wiki.apachemobilefilter.org

NOTE: this software need wurfl.xml you can download it directly from this site: http://wurfl.sourceforge.net or you can set the filter to download it directly.

=head1 SEE ALSO

Site: http://www.apachemobilefilter.org

=head1 AUTHOR

Idel Fuschini (idel.fuschini [at] gmail [dot] com)

=head1 COPYRIGHT

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
