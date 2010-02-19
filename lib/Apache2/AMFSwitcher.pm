#file:Apache2/AMFSwitcher.pm; 
#-------------------------------- 

#
# Created by Idel Fuschini 
# Date: 01/01/10
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
  $VERSION= "3.03";
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
  if ($ENV{LoadWebPatch}) {
      if ($ENV{LoadWebPatch} eq 'true') {
			  &loadConfigFile();
      } else {
	  	$CommonLib->printLog("LoadWebPatch not exist.	Please set the variable LoadWebPatch must be set with true value");
	  	$CommonLib->printLog("Pre-Requisite: WURFLFilter must be activated");
	  	ModPerl::Util::exit();
      }
  } else {
	  $CommonLib->printLog("LoadWebPatch must be set.	Please set the variable LoadWebPatch into httpd.conf with boolean value (true o false)");
	  $CommonLib->printLog("Pre-Requisite: WURFLFilter must be activated");
	  ModPerl::Util::exit();
  }
sub loadConfigFile {
	my $null="";
	my $null2="";
	my $null3="";
	my $val;
	my $capability;
	my $r_id;
	my $dummy;
	$CommonLib->printLog("AMFSwitcher: Start read configuration from httpd.conf");
	if ($ENV{MobileVersionUrl}) {
		$mobileversionurl=$ENV{MobileVersionUrl};
		$ArrayPath{1}=$ENV{MobileVersionUrl};
		$CommonLib->printLog("MobileVersionUrl is: $mobileversionurl");
		$mobileversionurl_ck=$ENV{MobileVersionUrl};
	}	
	if ($ENV{FullBrowserUrl}) {
		$fullbrowserurl=$ENV{FullBrowserUrl};
		$ArrayPath{2}=$ENV{FullBrowserUrl};
		$CommonLib->printLog("FullBrowserUrl is: $fullbrowserurl");
		$fullbrowserurl_ck=$ENV{FullBrowserUrl};
	}		
	if ($ENV{RedirectTranscoderUrl}) {
		$redirecttranscoderurl=$ENV{RedirectTranscoderUrl};
		$ArrayPath{3}=$ENV{RedirectTranscoderUrl};
		$redirecttranscoder="true";
		$redirecttranscoderurl_ck=$ENV{RedirectTranscoderUrl};
		$CommonLib->printLog("RedirectTranscoderUrl is: $redirecttranscoderurl");		
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
    my $uriAppend="";
    my $filter="true";
    if ($f->pnotes('device_claims_web_support')) {      
    	$device_claims_web_support=$f->pnotes('device_claims_web_support')
    }
    if ($f->pnotes('is_wireless_device')) {
        $is_wireless_device=$f->pnotes('is_wireless_device');
    }
    if ($f->pnotes('is_transcoder')) {
    	$is_transcoder=$f->pnotes('is_transcoder');
    }
    foreach my $string (@ExcludeString) {
        if (index($uri,$string) > 0) {
           $filter="false";
        } 
    }
    if ($filter eq "true"){
		if ($device_claims_web_support eq 'true' && $is_wireless_device eq 'false') {
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
		} else {
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
	    if ($is_transcoder eq 'true') {
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
	    if ($ArrayPath{$device_type} eq substr($uri,0,length($ArrayPath{$device_type}))) {
	    	$no_redirect=0;
	    }
		if ($location ne "none" ) {
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

For more details: http://www.idelfuschini.it/apache-mobile-filter-v2x.html

An example of how to set the httpd.conf is below:

=over 4

=item C<PerlSetEnv MOBILE_HOME server_root/MobileFilter>

This indicate to the filter where you want to redirect the specific family of devices:

=item C<PerlSetEnv FullBrowserUrl http://www.versionforpc.com>

=item C<PerlSetEnv MobileVersionUrl http://www.versionformobile.com>

=item C<PerlSetEnv PerlSetEnv RedirectTranscoderUrl http://www.versionfortrasncoder.com>

=item C<PerlTransHandler +Apache2::AMFSwitcher>

=back

NOTE: this software need wurfl.xml you can download it directly from this site: http://wurfl.sourceforge.net or you can set the filter to download it directly.

=head1 SEE ALSO

For more details: http://www.idelfuschini.it/apache-mobile-filter-v2x.html

Demo page of the filter: http://www.apachemobilefilter.org

=head1 AUTHOR

Idel Fuschini (idel.fuschini [at] gmail [dot] com)

=head1 COPYRIGHT

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
