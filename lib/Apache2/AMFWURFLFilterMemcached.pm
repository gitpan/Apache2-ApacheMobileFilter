#file:Apache2/AMFWURFLFilterMemcached.pm; 
#-------------------------------- 

#
# Created by Idel Fuschini 
# Date: 01/01/10
# Site: http://www.idelfuschini.it
# Mail: idel.fuschini@gmail.com


package Apache2::AMFWURFLFilterMemcached; 
  
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
  use Cache::Memcached;


  #
  # Define the global environment
  # 

  use vars qw($VERSION);
  my $CommonLib = new Apache2::AMFCommonLib ();
  $VERSION= "3.08";
  my %Capability;
  my %Array_fb;
  my %Array_id;
  my %Array_fullua_id;
  my %Array_DDRcapability;

  my %PatchArray_id;
  my %MobileArray;
  my %PCArray;
  $MobileArray{'mobile'}='mobile';
  $MobileArray{'symbian'}='mobile';
  $MobileArray{'midp'}='mobile';
  $MobileArray{'android'}='mobile';
  $MobileArray{'phone'}='mobile';
  $MobileArray{'ipod'}='mobile';
  $MobileArray{'google'}='mobile';
  $MobileArray{'novarra'}='mobile';
  $MobileArray{'htc'}='mobile';
  $MobileArray{'windows ce'}='mobile';
  $MobileArray{'palm'}='mobile';
  $MobileArray{'lge'}='mobile';
  $MobileArray{'brew'}='mobile';
  $MobileArray{'webos'}='mobile';
  $PCArray{'MSIE'}='msie';
  $PCArray{'MSIE 6'}='msie_6';
  $PCArray{'MSIE 7'}='msie_7';
  $PCArray{'MSIE 8'}='msie_8';
  my $mobileversionurl="none";
  my $fullbrowserurl="none";
  my $redirecttranscoder="true";
  my $redirecttranscoderurl="none";
  my $resizeimagedirectory="none";
  my $wurflnetdownload="false";
  my $downloadwurflurl="false";
  my $loadwebpatch="false";
  my $patchwurflnetdownload="false"; 
  my $patchwurflurl="";
  my $listall="false";
  my $cookiecachesystem="false";
  my $WURFLVersion="unknown";  
  my $serverMemCache;
  my $restmode='false';
  
  $CommonLib->printLog("---------------------------------------------------------------------------"); 
  $CommonLib->printLog("-------                 APACHE MOBILE FILTER V$VERSION                  -------");
  $CommonLib->printLog("-------         support http://amfticket.idelfuschini.it            -------");
  $CommonLib->printLog("---------------------------------------------------------------------------"); 
  $CommonLib->printLog("AMFWURFLFilterMemcached module Version $VERSION");
  if ($ENV{ResizeImageDirectory}) {
	  $Capability{'max_image_width'}="max_image_width";
	  $Capability{'max_image_height'}="max_image_width"; 
	  $resizeimagedirectory=$ENV{ResizeImageDirectory};
  } 
  if (($ENV{FullBrowserUrl}) || ($ENV{MobileVersionUrl})) {
	  $Capability{'device_claims_web_support'}="device_claims_web_support";
	  $Capability{'is_wireless_device'}="is_wireless_device";
	  $fullbrowserurl=$ENV{FullBrowserUrl} 
  } 
  if ($ENV{RedirectTranscoderUrl}) {
	  $Capability{'is_transcoder'}="is_transcoder";
	  $redirecttranscoderurl=$ENV{RedirectTranscoderUrl};
  }


  #
  # Check if AMFMobileHome and CacheDirectoryStore is setting in apache httpd.conf file for example:
  # PerlSetEnv AMFMobileHome <apache_directory>/MobileFilter
  # 
  my @Server;
  if ($ENV{ServerMemCached}) {
	$serverMemCache=$ENV{ServerMemCached};
	@Server = split(/,/, $ENV{ServerMemCached});
	$CommonLib->printLog("ServerMemCached is: $serverMemCache");
   } else {
	  $CommonLib->printLog("ServerMemCached is not setted. Please set the variable ServerMemCached into httpd.conf, example  \"PerlSetEnv ServerMemCached 10.10.10.10.:11211\"");
	  ModPerl::Util::exit();      
  }
  
  my $memd = new Cache::Memcached {
    'debug' => 0,
    'compress_threshold' => 10_000,
    'enable_compress' => 1,
  };
  $memd->set_servers(\@Server);

   $memd->set('AMFtest','test');
   if ($memd->get('AMFtest')) {
       $CommonLib->printLog("The AMF is connected to the Memcached server: $serverMemCache");
   } else {
       $CommonLib->printLog("The AMF is not connected to the Memcached server: $serverMemCache.");
	   ModPerl::Util::exit();      
   }
  $memd->set('device_not_found', "id=device_not_found&device=false&device_claims_web_support=true&is_wireless_device=false");
  if ($ENV{AMFMobileHome}) {
	  &loadConfigFile("$ENV{AMFMobileHome}/wurfl.xml");
  }  else {
	  $CommonLib->printLog("AMFMobileHome not exist (AMFMobileHome is deprecated).	Please set the variable AMFMobileHome into httpd.conf");
	  ModPerl::Util::exit();
  }
  

sub loadConfigFile {
	my ($fileWurfl) = @_;
	my $null="";
	my $null2="";
	my $null3="";  
	my $val;
	     my $capability;
	     my $r_id;
	     my $dummy;
	      	#The filter
	      	$CommonLib->printLog("Start read configuration from httpd.conf");
	
	      	 if ($ENV{WurflNetDownload}) {
				$wurflnetdownload=$ENV{WurflNetDownload};
				$CommonLib->printLog("WurflNetDownload is: $wurflnetdownload");
			 }	
	      	 if ($ENV{DownloadWurflURL}) {
				$downloadwurflurl=$ENV{DownloadWurflURL};
				$CommonLib->printLog("DownloadWurflURL is: $downloadwurflurl");
			 }	
	      	 if ($ENV{CapabilityList}) {
				my @dummycapability = split(/,/, $ENV{CapabilityList});
				foreach $dummy (@dummycapability) {
				      if ($dummy eq "all") {
				         $listall="true";
				      }
				      $Capability{$dummy}=$dummy;
				      $CommonLib->printLog("CapabilityList is: $dummy");
				}
			 } else {
				$listall="true";
				$CommonLib->printLog('CapabilityList not setted so the default value is "all"');
			 }	
	      	 if ($ENV{AMFMobileKeys}) {
				my @dummyMobileKeys = split(/,/, $ENV{AMFMobileKeys});
				foreach $dummy (@dummyMobileKeys) {
				      $MobileArray{$dummy}='mobile';
				}
				      $CommonLib->printLog("AMFMobileKeys is: $ENV{AMFMobileKeys}");
		} 	
	             
	      	 if ($ENV{LoadWebPatch}) {
				$loadwebpatch=$ENV{LoadWebPatch};
				$CommonLib->printLog("LoadWebPatch is: $loadwebpatch");
			 }	
	      	 if ($ENV{PatchWurflNetDownload}) {
				$patchwurflnetdownload=$ENV{PatchWurflNetDownload};
				$CommonLib->printLog("PatchWurflNetDownload is: $patchwurflnetdownload");
			 }	
	      	 if ($ENV{PatchWurflUrl}) {
				$patchwurflurl=$ENV{PatchWurflUrl};
				$CommonLib->printLog("PatchWurflUrl is: $patchwurflurl");
			 }	

			 if ($ENV{AMFProductionMode}) {
				$cookiecachesystem=$ENV{AMFProductionMode};
				$CommonLib->printLog("AMFProductionMode is: $cookiecachesystem");
			 } else {
				$CommonLib->printLog("AMFProductionMode (the CookieCacheSystem is deprecated) is not setted the default value is $cookiecachesystem");			   
			 }		
	

	    $CommonLib->printLog("Finish loading  parameter");
		$CommonLib->printLog("---------------------------------------------------------------------------"); 
	    if ($wurflnetdownload eq "true") {
	        $CommonLib->printLog("Start process downloading  WURFL.xml from $downloadwurflurl");
		        $CommonLib->printLog ("Test the  URL");
	        my ($content_type, $document_length, $modified_time, $expires, $server) = head($downloadwurflurl);
	        if ($content_type eq "") {
   		        $CommonLib->printLog("Couldn't get $downloadwurflurl.");
		   		ModPerl::Util::exit();
	        } else {
	            $CommonLib->printLog("The URL is correct");
	            $CommonLib->printLog("The size of document wurf file: $document_length bytes");	       
	        }
	        
	        if ($content_type eq 'application/zip') {
	              $CommonLib->printLog("The file is a zip file.");
	              $CommonLib->printLog ("Start downloading");
				  my @dummypairs = split(/\//, $downloadwurflurl);
				  my ($ext_zip) = $downloadwurflurl =~ /\.(\w+)$/;
				  my $filezip=$dummypairs[-1];
				  my $tmp_dir=$ENV{AMFMobileHome};
				  $filezip="$tmp_dir/$filezip";
				  my $status = getstore ($downloadwurflurl,$filezip);
				  my $output="$tmp_dir/tmp_wurfl.xml";
				  unzip $filezip => $output 
						or die "unzip failed: $UnzipError\n";
					#
					# call parseWURFLFile
					#
					callparseWURFLFile($output);

			} else {
				$CommonLib->printLog("The file is a xml file.");
			    my $content = get ($downloadwurflurl);
				my @rows = split(/\n/, $content);
				my $row;
				my $count=0;
				foreach $row (@rows){
					$r_id=parseWURFLFile($row,$r_id);
				}
			}
			$CommonLib->printLog("Finish downloading WURFL from $downloadwurflurl");

	    } else {
			if (-e "$fileWurfl") {
					$CommonLib->printLog("Start loading  WURFL.xml");
					if (open (IN,"$fileWurfl")) {
						while (<IN>) {
							 $r_id=parseWURFLFile($_,$r_id);
							 
						}
						close IN;
					} else {
					    $CommonLib->printLog("Error open file:$fileWurfl");
					    ModPerl::Util::exit();
					}
			} else {
			  $CommonLib->printLog("File $fileWurfl not found");
			  ModPerl::Util::exit();
			}
		}
		close IN;
		#
		# Start for web_patch_wurfl (full browser)
		#
		if ($loadwebpatch eq 'true') {
			if ($patchwurflnetdownload eq "true") {
				$CommonLib->printLog("Start downloading patch WURFL from $patchwurflurl");
			    my ($content_type, $document_length, $modified_time, $expires, $server) = head($patchwurflurl);
		        if ($content_type eq "") {
	   		        $CommonLib->printLog("Couldn't get $patchwurflurl.");
			   		ModPerl::Util::exit();
		        } else {
		            $CommonLib->printLog("The URL for download patch WURFL is correct");
		            $CommonLib->printLog("The size of document is: $document_length bytes");	       
		        }
				my $content = get ($patchwurflurl);
				$CommonLib->printLog("Finish downloading  WURFL.xml");
				if ($content eq "") {
					$CommonLib->printLog("Couldn't get patch $patchwurflurl.");
					ModPerl::Util::exit();
				}
				my @rows = split(/\n/, $content);
				my $row;
				my $count=0;
				foreach $row (@rows){
					$r_id=parsePatchFile($row,$r_id);
				}
	         } else {
				my $filePatch="$ENV{AMFMobileHome}/web_browsers_patch.xml";
				if (-e "$filePatch") {
						$CommonLib->printLog("Start loading Web Patch File of WURFL");
						if (open (IN,"$filePatch")) {
							while (<IN>) {
								 $r_id=parsePatchFile($_,$r_id);
								 
							}
							close IN;
						} else {
							$CommonLib->printLog("Error open file:$filePatch");
							ModPerl::Util::exit();
						}
				} else {
				  $CommonLib->printLog("File patch $filePatch not found");
				  ModPerl::Util::exit();
				}
			}
		}



		my $arrLen = scalar %Array_fb;
		($arrLen,$dummy)= split(/\//, $arrLen);
		if ($arrLen == 0) {
		     $CommonLib->printLog("Error the file probably is not a wurfl file, control the url or path");
		     $CommonLib->printLog("Control also if the file is compress file, and DownloadZipFile parameter is seted false");
		     #ModPerl::Util::exit();
		}
       # if ($memd->get('ResizeImageDirectory') ne $resizeimagedirectory||$memd->get('DownloadWurflURL') ne $downloadwurflurl||$memd->get('FullBrowserUrl') ne $fullbrowserurl||$memd->get('RedirectTranscoderUrl') ne $redirecttranscoderurl || $memd->get('ver') ne $WURFLVersion || $memd->get('caplist') ne $ENV{CapabilityList}||$memd->get('listall') ne $listall) {
       #     $CommonLib->printLog("********************************************************************************************************");
       #     $CommonLib->printLog("* This is a new version of WURFL or you change some parameter value, now the old cache must be deleted *");
       #     $CommonLib->printLog("********************************************************************************************************");
       #     $memd->flush_all();
	   #     $memd->set('ver', $WURFLVersion);
	    #    $memd->set('caplist', $ENV{CapabilityList});
	     #   $memd->set('listall', $listall);
	      #  $memd->set('RedirectTranscoderUrl', $redirecttranscoderurl);
	       # $memd->set('FullBrowserUrl', $fullbrowserurl);
	       # $memd->set('DownloadWurflURL', $downloadwurflurl);
	       # $memd->set('ResizeImageDirectory', $resizeimagedirectory);
        #}
		
        $CommonLib->printLog("WURFL version: $WURFLVersion");
        $CommonLib->printLog("This version of WURFL has $arrLen UserAgent");
        $CommonLib->printLog("End loading  WURFL.xml");
	if ($ENV{RestMode}) {
		$restmode=$ENV{RestMode};
		$CommonLib->printLog("RestMode is: $restmode");
	}
}
sub FallBack {
  my ($idToFind) = @_;
  my $dummy_id;
  my $dummy;
  my $dummy2;
  my $LOOP;
  my %ArrayCapFoundToPass;
  my $capability;
   foreach $capability (sort keys %Capability) {
        $dummy_id=$idToFind;
        $LOOP=0;
   		while ($LOOP==0) {   		    
   		    $dummy="$dummy_id|$capability";
        	if ($Array_DDRcapability{$dummy}) {        	  
        	   $LOOP=1;
        	   $dummy2="$dummy_id|$capability";
        	   $ArrayCapFoundToPass{$capability}=$Array_DDRcapability{$dummy2};
        	} else {
        	      if ($Array_fb{$dummy_id}) {
	        	  		$dummy_id=$Array_fb{$dummy_id};        
        	      } else {
        	         $dummy_id="root";
        	      }
	        	  if ($dummy_id eq "root" || $dummy_id eq "generic") {
	        	    $LOOP=1;
	        	  }
        	}   
   		}
   		
}
   return %ArrayCapFoundToPass;
}
sub IdentifyUAMethod {
  my ($UserAgent) = @_;
  my $ind=0;
  my %ArrayPM;
  my $pair; 
  my $pair2;
  my $id_find="";
  my $dummy;
  my $ua_toMatch;
  my $near_toFind=100;
  my $near_toMatch;
  my %ArrayUAType=$CommonLib->GetMultipleUa($UserAgent);  
  foreach $pair (reverse sort { $a <=> $b }  keys	 %ArrayUAType)
  {
      my $dummy=$ArrayUAType{$pair};
      if ($Array_id{$dummy}) {
         if ($id_find) {
           my $dummy2="";
         } else {
           $id_find=$Array_id{$dummy};
         }
      }
  }
  return $id_find;
}
sub IdentifyPCUAMethod {
  my ($UserAgent) = @_;
  my $ind=0;
  my $id_find="";
  my $pair;
  my $length=0;
  foreach $pair (sort %PCArray) {
	if ($UserAgent =~ m/$pair/) {
		$id_find=$PCArray{$pair};
	}
  }
  if ($id_find eq "") { 
	foreach $pair (%PatchArray_id)
	{  
	     if (index($UserAgent,$pair) > -1) {
		      $id_find=$PatchArray_id{$pair};
	     }
	}
  }
  return $id_find;
}
sub callparseWURFLFile {
	 my ($output) = @_;
	 my $r_id;
	if (open (IN,"$output")) {
		while (<IN>) {
			$r_id=parseWURFLFile($_,$r_id);
		}
		close IN;			  
	} else {
			$CommonLib->printLog("Error open file:$output");
			ModPerl::Util::exit();
	}
}
sub parseWURFLFile {
         my ($record,$val) = @_;
		 my $null="";
		 my $null2="";
		 my $null3="";
		 my $ua="";
		 my $fb="";
		 my $value="";
		 my $id;
		 my $name="";
		 if ($val) {
		    $id="$val";
		 } 
	     if ($record =~ /\<device/o) {
	        if (index($record,'user_agent') > 0 ) {
	           $ua=substr($record,index($record,'user_agent') + 12,index($record,'"',index($record,'user_agent')+ 13)- index($record,'user_agent') - 12);
			  if (index($ua,'BlackBerry') >0 ) {
					$ua=substr($ua,index($ua,'BlackBerry'));
			  }
	        }	        
	        if (index($record,'id') > 0 ) {
	           $id=substr($record,index($record,'id') + 4,index($record,'"',index($record,'id')+ 5)- index($record,'id') - 4);	
	        }	        
	        if (index($record,'fall_back') > 0 ) {
	           $fb=substr($record,index($record,'fall_back') + 11,index($record,'"',index($record,'fall_back')+ 12)- index($record,'fall_back') - 11);	           
	        }
	        if (($fb) && ($id)) {	     	   
					$Array_fb{"$id"}=$fb;
				 }
				 if (($ua) && ($id)) {
				         my %ParseUA=$CommonLib->GetMultipleUa($ua);
				         my $pair;
				         my $arrUaLen = scalar %ParseUA;
				         my $contaUA=0;
				         my $Array_fullua_id=$ua;
				         foreach $pair (reverse sort { $a <=> $b }  keys %ParseUA) {
						 			my $dummy=$ParseUA{$pair};
						            $Array_id{$dummy}=$id;
				                $contaUA=$contaUA-1;
						 }
				 }
				 
		 }
		 if ($record =~ /\<capability/o) { 
			($null,$name,$null2,$value,$null3,$fb)=split(/\"/, $record);
			if ($listall eq "true") {
				$Capability{$name}=$name;
			}
			if (($id) && ($Capability{$name}) && ($name) && ($value)) {			   
			   $Array_DDRcapability{"$val|$name"}=$value;
			}
		 }
		 if ($record =~ /\<ver/o) {
		     $WURFLVersion=$CommonLib->extValueTag("ver",$record);
		 }
		 return $id;

}
sub parsePatchFile {
         my ($record,$val) = @_;
		 my $null="";
		 my $null2="";
		 my $null3="";
		 my $ua="";
		 my $fb="";
		 my $value="";
		 my $id;
		 my $name="";
		 if ($val) {
		    $id="$val";
		 } 
	     if ($record =~ /\<device/o) {
	        if (index($record,'user_agent') > 0 ) {
	           $ua=substr($record,index($record,'user_agent') + 12,index($record,'"',index($record,'user_agent')+ 13)- index($record,'user_agent') - 12);
			  if (index($ua,'BlackBerry') >0 ) {
					$ua=substr($ua,index($ua,'BlackBerry'));
			  }
	        }	        
	        if (index($record,'id') > 0 ) {
	           $id=substr($record,index($record,'id') + 4,index($record,'"',index($record,'id')+ 5)- index($record,'id') - 4);	
	        }	        
	        if (index($record,'fall_back') > 0 ) {
	           $fb=substr($record,index($record,'fall_back') + 11,index($record,'"',index($record,'fall_back')+ 12)- index($record,'fall_back') - 11);	           
	        }
	        if (($fb) && ($id)) {	     	   
					$Array_fb{"$id"}=$fb;
				 }
				 if (($ua) && ($id)) {
				         #if (index($id,'_') > 0) {
			             	$PatchArray_id{$ua}=$id;
				         #}
			             $Array_id{$ua}=$id;

				 }				 
		 }
		 if ($record =~ /\<capability/o) { 
			($null,$name,$null2,$value,$null3,$fb)=split(/\"/, $record);
			if ($listall eq "true") {
				$Capability{$name}=$name;
			}
			if (($id) && ($Capability{$name}) && ($name) && ($value)) {			   
			   $Array_DDRcapability{"$val|$name"}=$value;
			}
		 }
		 return $id;

}

sub handler {
    my $f = shift;  
    my $capability2;
    my $variabile="";
    my $user_agent=$f->headers_in->{'User-Agent'}|| '';
    my $x_user_agent=$f->headers_in->{'X-Device-User-Agent'}|| '';
    my $x_operamini_phone_ua=$f->headers_in->{'X-OperaMini-Phone-Ua'}|| '';
    my $x_operamini_ua=$f->headers_in->{'X-OperaMini-Ua'}|| '';
    my $query_string=$f->args;
    my $docroot = $f->document_root();
    my $id="";
    my $location="none";
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
    

    if ($x_user_agent) {
       $user_agent=$x_user_agent;
    }	  
    if ($x_operamini_phone_ua) {
       $user_agent=$x_operamini_phone_ua;
    }
    if (($query_string) && $restmode eq 'true') {
    		  my @vars = split(/&/, $query_string); 	  
    		  foreach $var (sort @vars){
    				   if ($var) {
    						my ($v,$i) = split(/=/, $var);
    						$v =~ tr/+/ /;
    						$v =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    						$i =~ tr/+/ /;
    						$i =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    						$i =~ s/<!--(.|\n)*-->//g;
    						$ArrayQuery{$v}=$i;
    					}
    		  }
    	  if ($ArrayQuery{amf}) {
    				$user_agent=$ArrayQuery{amf};
    	  }

    }    

	if ($user_agent =~ m/Blackberry/i) {	 
		$user_agent=substr($user_agent,index($user_agent,'BlackBerry'));
		$mobile=1;
	}
	if ($user_agent =~ m/UP.link/i ) {
		$user_agent=substr($user_agent,0,index($user_agent,'UP.Link') - 1);
		$mobile=1;
	}
    my $cookie = $f->headers_in->{Cookie} || '';
    $id=$CommonLib->readCookie($cookie);
    if ($id eq ""){
                  if ($user_agent) {
					my $lcuser_agent=lc($user_agent);
	  			    if ($mobile==0) {
						foreach my $pair (%MobileArray) {
							if ($user_agent =~ m/$pair/i) {
								$mobile=1;
							}
						}
						if ($mobile==0) {						
							$id=IdentifyPCUAMethod($user_agent);
						}			            
					}
					if ($id eq "") { 
							$id=IdentifyUAMethod($user_agent);
					}
				  }	
     }                        
     if ($id ne "") {
	      	     #
	      	     #  device detected 
	      	     #
	      	     my $var=$memd->get("$id");
		         if ($var) {
					my @pairs = split(/&/, $var);
					my $param_tofound;
					my $string_tofound;
					foreach $param_tofound (@pairs) {      	       
						($string_tofound,$dummy)=split(/=/, $param_tofound);
						$ArrayCapFound{$string_tofound}=$dummy;
						my $upper2=uc($string_tofound);
						$f->subprocess_env("AMF_$upper2" => $ArrayCapFound{$string_tofound});
						$f->pnotes("$string_tofound" => $ArrayCapFound{$string_tofound});
					}
					$id=$ArrayCapFound{id};								   
			} else {
					%ArrayCapFound=FallBack($id);         
					foreach $capability2 (sort keys %ArrayCapFound) {
						$variabile2="$variabile2$capability2=$ArrayCapFound{$capability2}&";
						my $upper=uc($capability2);
						$f->subprocess_env("AMF_$upper" => $ArrayCapFound{$capability2});
						$f->pnotes("$capability2" => $ArrayCapFound{$capability2});
					}
					$variabile2="id=$id&$variabile2";
					$f->subprocess_env("AMF_ID" => $id);
					$f->pnotes('id' => $id);
					$memd->set("$id",$variabile2);
			}
			if ($cookiecachesystem eq "true") {
						$f->err_headers_out->set('Set-Cookie' => "amf=$id; path=/;");	
			}		  			  
	} else {
	      	     #
	      	     # unknown device 
	      	     #
				 if ($cookiecachesystem eq "true") {
							$f->err_headers_out->set('Set-Cookie' => "amf=device_not_found; path=/;");	
				  }		  			  
	}
    
	$f->subprocess_env("AMF_VER" => $VERSION);
	$f->subprocess_env("AMF_WURFLVER" => $WURFLVersion);
	if ($x_operamini_ua) {
	    $f->subprocess_env("AMF_MOBILE_BROWSER" => $x_operamini_ua);
	    $f->pnotes("mobile_browser" => $x_operamini_ua);
	    $f->subprocess_env("AMF_IS_TRANCODER" => 'true');		
	    $f->pnotes("is_transcoder" => 'true');
	}
	return Apache2::Const::DECLINED;
}
1; 
__END__
	
=head1 NAME

Apache2::AMFWURFLFilterMemcached - The module detects the mobile device and passes the WURFL capabilities on to the other web application as environment variables

=head1 SEE ALSO

For more details: http://www.idelfuschini.it/apache-mobile-filter-v2x.html

Demo page of the filter: http://www.apachemobilefilter.org

=head1 AUTHOR

Idel Fuschini (idel.fuschini [at] gmail [dot] com)

=head1 COPYRIGHT

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
