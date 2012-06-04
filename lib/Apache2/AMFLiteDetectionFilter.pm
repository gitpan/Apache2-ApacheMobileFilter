#file:Apache2/AMFWURFLFilter.pm; 
#-------------------------------- 

#
# Created by Idel Fuschini 
# Date: 01/08/10
# Site: http://www.apachemobilefilter.org
# Mail: idel.fuschini@gmail.com


package Apache2::AMFLiteDetectionFilter; 
  
  use strict; 
  use warnings;
  use MIME::Base64 qw(encode_base64);
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
  use Cache::FileBackend;


  #
  # Define the global environment
  # 

  use vars qw($VERSION);
  $VERSION= "3.53";
  my $CommonLib = new Apache2::AMFCommonLib ();
  my %MobileArray;#=$CommonLib->getMobileArray;
  my %MobileTabletArray;
  my $cookiecachesystem="false";
  my $restmode='false';
  my $downloadparamurl='true';
  my $configMobileFile;
  my $forcetablet='true';
  my $configTabletFile;
  my $checkVersion='true';
  my $mobilenable="false";
  
  my $urlmobile="http://www.apachemobilefilter.org/param/litemobiledetection.config";
  my $urlTablet="http://www.apachemobilefilter.org/param/litetabletdetection.config";
  $CommonLib->printLog("---------------------------------------------------------------------------"); 
  $CommonLib->printLog("-------                 APACHE MOBILE FILTER V$VERSION                  -------");
  $CommonLib->printLog("------- support http://groups.google.com/group/amf-device-detection -------");
  $CommonLib->printLog("---------------------------------------------------------------------------");
  $CommonLib->printLog("----------------- AMF Lite Detection (not DR required)  -------------------");
  $CommonLib->printLog("---------------------------------------------------------------------------");
  $CommonLib->printLog("AMFLiteDetectionFilter module Version $VERSION");
  if ($ENV{AMFCheckVersion}) {
	$checkVersion=$ENV{AMFCheckVersion};
  }
  if ($checkVersion eq 'true') {
	$CommonLib->printLog("Check on apchemobilefilter.org if the installed AMF is the last version");  
        $CommonLib->printLog("Try to download http://www.apachemobilefilter.org/param/amf.config");
	my $url="http://www.apachemobilefilter.org/param/amf.config";
	my $content = get ($url);
	$content =~ s/\n//g;
	my $check_version=0;
	if ($content) {
	  $check_version=$content;
	}
        if ($check_version > $VERSION && $check_version ne 0) {
	       $CommonLib->printLog("---------------------------------------------------------------------------");
	       $CommonLib->printLog("-----           There is a new version of AMF V$check_version online             ----");
	       $CommonLib->printLog("---------------------------------------------------------------------------");
	} else {
		$CommonLib->printLog("AMF installed is the last version");
	}
  } else {
	$CommonLib->printLog("AMFCheckVersion is false, AMF don't check the last version.");
  }
  if ($ENV{AMFMobileHome}) {
	  $configMobileFile="$ENV{AMFMobileHome}/amflitedetection.config";
	  $configTabletFile="$ENV{AMFMobileHome}/amflitedetection_tablet.config";
   }  else {
	  $CommonLib->printLog("AMFMobileHome not exist. Please set the variable AMFMobileHome into httpd.conf");
	  ModPerl::Util::exit();
   }
   if ($ENV{AMFProductionMode}) {
	$cookiecachesystem=$ENV{AMFProductionMode};
	$CommonLib->printLog("AMFProductionMode is: $cookiecachesystem");
   } else {
	$CommonLib->printLog("AMFProductionMode is not setted the default value is $cookiecachesystem");			   
   }
   if ($ENV{AMFMobileKeys}) {
	my @dummyMobileKeys = split(/,/, $ENV{AMFMobileKeys});
	foreach my $dummy (@dummyMobileKeys) {
		$MobileArray{$dummy}='mobile';
	}
	$CommonLib->printLog("AMFMobileKeys is: $ENV{AMFMobileKeys}");
    }
    if ($ENV{RestMode}) {
			$restmode=$ENV{RestMode};
			$CommonLib->printLog("RestMode is: $restmode");
    }
    if ($ENV{AMFDownloadParamURL}) {
	                        $downloadparamurl=$ENV{AMFDownloadParamURL};
				$CommonLib->printLog("DownloadAMFParamURL is: $downloadparamurl");
    }
    if ($downloadparamurl eq 'true') {
        &readMobileParamFromUrl;	
        &readTabletParamFromUrl;
    } else {
	&readMobileParamFromFile;		
        &readTabletParamFromFile;
    }
    if ($ENV{ForceTabletAsFullBrowser}) {
		if ($ENV{ForceTabletAsFullBrowser} eq 'true') {
			$CommonLib->printLog("AMFMobileHome not exist. Please set the variable AMFMobileHome into httpd.conf");
			$forcetablet="true";
		} else {
			$forcetablet="false";
		}
     }
     if ($ENV{FullBrowserMobileAccessKey}) {
                          $mobilenable="$ENV{FullBrowserMobileAccessKey}";
                          $CommonLib->printLog("FullBrowserMobileAccessKey is: $ENV{FullBrowserMobileAccessKey}");
                          $CommonLib->printLog("For access the device to fullbrowser set the link: <url>?$mobilenable=true");
     }
sub readMobileParamFromUrl {
		$CommonLib->printLog("Read data from apachemobilefilter.org");
		my $content = get ($urlmobile);
		if ($content) {
			$CommonLib->printLog("Download OK");
			$content =~ s/\n//g;
			my @dummyMobileKeys = split(/,/, lc($content));
			foreach my $dummy (@dummyMobileKeys) {
				$MobileArray{$dummy}='mobile';
			}
			 open (MYFILE, ">$configMobileFile") || die ("Cannot Open File: $configMobileFile");
			    print MYFILE $content;
			 close (MYFILE);
		 } else {
			$CommonLib->printLog("Download error from apachemobilefilter.org");
			$CommonLib->printLog("Try download previews version");
			&readMobileParamFromFile;	
		}
}
sub readMobileParamFromFile {
		$CommonLib->printLog("Read for mobile data from $configMobileFile");
		my $content="";
		if (open (IN,$configMobileFile)) {
			while (<IN>) {
				$content=$content.$_;				 
			}
			close IN;
		} else {
			$CommonLib->printLog("Error open file:$configMobileFile");
			ModPerl::Util::exit();
		}
                $content =~ s/\n//g;
		my @dummyMobileKeys = split(/,/, lc($content));
		foreach my $dummy (@dummyMobileKeys) {
			$MobileArray{$dummy}='mobile';
		}
}
sub readTabletParamFromUrl {
		$CommonLib->printLog("Read data for tablet detection from apachemobilefilter.org");
		my $content = get ($urlTablet);
		if ($content) {
			$CommonLib->printLog("Download OK");
			$content =~ s/\n//g;
			my @dummyMobileKeys = split(/,/, lc($content));
			foreach my $dummy (@dummyMobileKeys) {
				$MobileTabletArray{$dummy}='mobile';
			}
			 open (MYFILE, ">$configMobileFile") || die ("Cannot Open File: $configMobileFile");
			    print MYFILE $content;
			 close (MYFILE);
		 } else {
			$CommonLib->printLog("Download error from apachemobilefilter.org");
			$CommonLib->printLog("Try download previews version");
			&readTabletParamFromFile;	
		}
}
sub readTabletParamFromFile {
		$CommonLib->printLog("Read data from $configTabletFile");
		my $content="";
		if (open (IN,$configTabletFile)) {
			while (<IN>) {
				$content=$content.$_;				 
			}
			close IN;
		} else {
			$CommonLib->printLog("Error open file:$configTabletFile");
			ModPerl::Util::exit();
		}
                $content =~ s/\n//g;
		my @dummyMobileKeys = split(/,/, lc($content));
		foreach my $dummy (@dummyMobileKeys) {
			$MobileTabletArray{$dummy}='mobile';
		}
}

sub isMobile {
  my ($UserAgent) = @_;
  my $ind=0;
  my $isMobileValue='false';
  my $pair;
  my $length=0;
  foreach $pair (sort keys %MobileArray) {
	if ($UserAgent =~ m/$pair/) {
		$isMobileValue='true';
	}
  }
  return $isMobileValue;
}
sub isTablet {
  my ($UserAgent) = @_;
  my $ind=0;
  my $isTabletValue='false';
  my $pair;
  my $length=0;
  foreach $pair (sort keys %MobileTabletArray) {
	if ($UserAgent =~ m/$pair/) {
		$isTabletValue='true';
	}
  }
  return $isTabletValue;
}
sub handler {
    my $f = shift;  
    my $capability2;
    my $variabile="";
    my $user_agent=lc($f->headers_in->{'User-Agent'}|| '');
    my $x_user_agent=$f->headers_in->{'X-Device-User-Agent'}|| '';
    my $x_operamini_phone_ua=$f->headers_in->{'X-OperaMini-Phone-Ua'}|| '';
    my $x_operamini_ua=$f->headers_in->{'X-OperaMini-Ua'}|| '';
    my $query_string=$f->args;
    my $docroot = $f->document_root();
    my $id="";
    my $location="none";
    my $isTablet="false";
    my $width_toSearch;
    my $type_redirect="internal";
    my $return_value;
    my $dummy="";
    my $variabile2="";
    my %ArrayCapFound;
    my $controlCookie;
    my $query_img="";
    $ArrayCapFound{is_transcoder}='false';
    my %ArrayQuery;
    my $var;
    my $mobile=0;
    my $version="";
    if ($user_agent eq "") {
	$user_agent="no useragent found";
    }
    if ($x_user_agent) {
       $user_agent=lc($x_user_agent);
    }	  
    if ($x_operamini_phone_ua) {
       $user_agent=lc($x_operamini_phone_ua);
    }
    my $cookie = $f->headers_in->{Cookie} || '';
    my $amf_device_ismobile=$CommonLib->readCookie($cookie);
    my $amfFull=$CommonLib->readCookie_fullB($cookie);
    if ($query_string) {
    		  my @vars = split(/&/, $query_string); 	  
    		  foreach $var (sort @vars){
    			if ($var) {
    				my ($v,$i) = split(/=/, $var);
    				$v =~ tr/+/ /;
    				$v =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
				if ($i) {
					$i =~ tr/+/ /;
					$i =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
					$i =~ s/<!--(.|\n)*-->//g;
					$ArrayQuery{$v}=$i;
				}
    			}
    		  }
          if ($ArrayQuery{$mobilenable}) {
                $f->err_headers_out->set('Set-Cookie' => "amfFull=false; path=/;");
                $amfFull='ok';
          }    

    }
	if ($amf_device_ismobile eq "") {
		$amf_device_ismobile = &isMobile($user_agent);
		if ($cookiecachesystem eq "true") {
			$f->err_headers_out->set('Set-Cookie' => "amfID=$id; path=/;");	
		}	
	}
	my $amf_device_istablet=&isTablet($user_agent);
        if ($amfFull ne "") {
            $f->subprocess_env("AMF_FORCE_TO_DESKTOP" => 'true');
            $f->pnotes("amf_force_to_desktop" => 'true');
        }
	$f->pnotes('is_tablet' => $amf_device_istablet);
	$f->pnotes("amf_device_ismobile" => $amf_device_ismobile);
	$f->subprocess_env("AMF_ID" => "amf_lite_detection");
	$f->subprocess_env("AMF_DEVICE_IS_MOBILE" => $amf_device_ismobile);
	$f->subprocess_env("AMF_DEVICE_IS_TABLET" => $amf_device_istablet);
	$f->subprocess_env("AMF_VER" => $VERSION);
	$f->headers_out->set("AMF-Ver"=> $VERSION);
	if ($x_operamini_ua) {
	    $f->subprocess_env("AMF_MOBILE_BROWSER" => $x_operamini_ua);
	    $f->pnotes("mobile_browser" => $x_operamini_ua);
	    $f->subprocess_env("AMF_IS_TRANCODER" => 'true');		
	    $f->pnotes("is_transcoder" => 'true');
	} else {
	    $f->pnotes("is_transcoder" => 'true');
	}
	return Apache2::Const::DECLINED;
}
1; 

	
=head1 NAME

Apache2::AMFLiteDetectionFilter - The module detects in lite mode the mobile device and passes few capabilities on to the other web application as environment variables

=head1 DESCRIPTION

Module for device detection, parse the user agent and decide if the device is mobile or not.

=head1 AMF PROJECT SITE

http://www.apachemobilefilter.org

=head1 DOCUMENTATION

http://wiki.apachemobilefilter.org

Perl Module Documentation: http://wiki.apachemobilefilter.org/index.php/AMFLiteDetectionFilter

=head1 AUTHOR

Idel Fuschini (idel.fuschini [at] gmail [dot] com)

=head1 COPYRIGHT

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut

