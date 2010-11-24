#file:Apache2/AMFImageRendering.pm; 
#-------------------------------- 

#
# Created by Idel Fuschini 
# Date: 01/08/10
# Site: http://www.idelfuschini.it
# Mail: idel.fuschini@gmail.com



package Apache2::AMFImageRendering; 
  
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
  use Image::Resize;
  use File::Copy;
  use Apache2::Const -compile => qw(OK REDIRECT DECLINED HTTP_MOVED_TEMPORARILY);
  use constant BUFF_LEN => 1024;


  #
  # Define the global environment
  # 

  use vars qw($VERSION);
  $VERSION= "3.21";
  my $CommonLib = new Apache2::AMFCommonLib ();
  my %Capability;
  my %Array_fb;
  my %Array_id;
  my %Array_fullua_id;
  my %Array_DDRcapability;

  my %XHTMLUrl;
  my %WMLUrl;
  my %CHTMLUrl;
  my %ImageType;
  my %cacheArray;
  my %cacheArray_toview;
  

  my $intelliswitch="false";
  my $mobileversionurl;
  my $fullbrowserurl;
  my $querystring="false";
  my $showdefaultvariable="false";
  my $wurflnetdownload="false";
  my $downloadwurflurl="false";
  my $resizeimagedirectory="";
  my $downloadzipfile="true";
  my $virtualdirectoryimages="false";
  my $virtualdirectory="";
  my $repasshanlder=0;
  my $globalpassvariable="";
  my $log4wurfl="";
  my $loadwebpatch="false";
  my $dirwebpatch="";
  my $patchwurflnetdownload="false"; 
  my $patchwurflurl="";
  my $redirecttranscoder="true";
  my $redirecttranscoderurl="";
  my $detectaccuracy="false";
  my $listall="false";
  my $resizeimagesmall="false";
  my $par_height='height';
  my $par_width='width';
  my $par_perc='dim';
  
  $ImageType{'image/png'}="png";
  $ImageType{'image/gif'}="gif";
  $ImageType{'image/jpg'}="jpg";
  $ImageType{'image/jpeg'}="jpeg";
  
  #
  # Check if MOBILE_HOME is setting in apache httpd.conf file for example:
  # PerlSetEnv MOBILE_HOME <apache_directory>/MobileFilter
  #
  $CommonLib->printLog("---------------------------------------------------------------------------"); 
  $CommonLib->printLog("AMFImageRendering Version $VERSION");
  if ($ENV{AMFMobileHome}) {
	  &loadConfigFile();
  } else {
	  $CommonLib->printLog("AMFMobileHome not exist.	Please set the variable AMFMobileHome into httpd.conf");
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
	      	#The filter
	      	$CommonLib->printLog("ResizeImageDirectory: Start read configuration from httpd.conf");
	      	 if ($ENV{ResizeImageDirectory}) {
				$resizeimagedirectory=$ENV{ResizeImageDirectory};
				$CommonLib->printLog("ResizeImageDirectory is: $resizeimagedirectory");
			 } else {
			    $CommonLib->printLog("ERROR: ResizeImageDirectory parameter must be setted");
			    ModPerl::Util::exit();
		}
		if ($ENV{ResizeSmallImage}) {
			$resizeimagesmall=$ENV{ResizeSmallImage};
			$CommonLib->printLog("ResizeSmallImage is: $resizeimagesmall. The image smallest of device screensize is also resized (low quality)");
		}
	      	if ($ENV{ImageParamWidth}) {
				$par_width=$ENV{ImageParamWidth};
				$CommonLib->printLog("ImageParamWidth is: $par_width. To force the width of image the url must be <url image>?$par_width=<width>");
		} 
	      	if ($ENV{ImageParamHeight}) {
				$par_height=$ENV{ImageParamHeight};
				$CommonLib->printLog("ImageParamHeight is: $par_height. To force the height of image the url must be <url image>?$par_width=<height>");
		} 
	      	if ($ENV{ImageParamPerc}) {
				$par_perc=$ENV{ImageParamPerc};
				$CommonLib->printLog("ImageParamPerc is: $par_perc. To force the percentage of image the url must be <url image>?$par_perc=<percentage>");
		} 

	    $CommonLib->printLog("Finish loading  parameter");
}
sub handler    {
      my $f = shift;
      my $capability2;
      my $s = $f->r->server;
      my $query_string=$f->r->args;
      my $uri = $f->r->uri();
      $uri =~ s/\//_/g;
      my $content_type=$f->r->content_type();
      my @fileArray = split(/\//, $uri);
      my $file=$fileArray[-1];
      my $docroot = $f->r->document_root();
      $docroot =~ s/\//_/g;
      my $servername=$f->r->get_server_name();
      my $id="";
      my $method="";     
      my $location;
      my $width_toSearch;
      my $type_redirect="internal";
      my $return_value=Apache2::Const::DECLINED;
	  my $dummy="";
	  my $variabile2="";
	  my %ArrayCapFound;
	  my $controlCookie;
	  my $query_img="";
      my %ArrayQuery;
      my $var;
      my $cookie = $f->r->headers_in->{Cookie} || '';
      my $width=1000;
      my $height=1000;
      my $image2="";
      $content_type=lc($content_type);
      if ($f->r->pnotes('max_image_width')) {      
      	$width=$f->r->pnotes('max_image_width')
      }
      if ($f->r->pnotes('max_image_height')) {
         $height=$f->r->pnotes('max_image_height');
      }
      $repasshanlder=$repasshanlder + 1;
 	  #
 	  # Reading value of query string 
 	  #
      if ($query_string) {
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
 	  }      
	  if ($ImageType{$content_type}) {
	          my $imageToConvert;
	          my $imagefile="";
				  if ($ArrayQuery{par_height}) {
				       if ( $ArrayQuery{$par_height} =~ /^-?\d/) {
				       		$height=$ArrayQuery{par_height};
				       }
				  }
				  if ($ArrayQuery{$par_width}) {
				       if ( $ArrayQuery{$par_width} =~ /^-?\d/) {
				       		$width=$ArrayQuery{$par_width};
				       }
				  }

				  if ($ArrayQuery{$par_perc}) {
				       if ( $ArrayQuery{$par_perc} =~ /^-?\d/) {
				       		$width=$ArrayQuery{$par_perc} * $width / 100;
				       }
				  }
				  $imagefile="$resizeimagedirectory/$docroot-$uri.$width";
				  #
				  # control if image exist
				  #
				  $imageToConvert=$f->r->filename();
				  $return_value=Apache2::Const::DECLINED;
				  if ( -e "$imageToConvert") {
						  
					  my $filesize; 
					  if ( -e "$imagefile") {
					  } else { 
						  my $image = Image::Resize->new("$imageToConvert");
						  if ($image->width() < $width && $resizeimagesmall eq 'false') {
							copy($imageToConvert, $imagefile);
     					          } else {
						  my $gd = $image->resize($width, $height);
						  
						  if (open(FH, ">$imagefile")) {
							if ($content_type eq "image/gif") {
								$image2=$gd->gif();
								print FH $image2;								
							}
							if ($content_type eq "image/jpeg") {
								$image2=$gd->jpeg();
								print FH $image2;
							}
							if ($content_type eq "image/png") {
								$image2=$gd->png();
								print FH $image2;
							}
						  close(FH);
						  } else {
					         $s->warn("Can not create $imagefile");
						 }
						 }
					  }
					     unless( $f->ctx ) { 
					       $f->r->headers_out->unset('Content-Length'); 
					       $f->ctx(1); 
					    }
					  $filesize = -s "$imagefile";
					  $f->r->headers_out->set(Pragma => 'no-cache');
					  $f->r->headers_out->set('Cache-control' => 'no-cache');
					  $f->r->headers_out->set(Expires => '-1');
					  $f->r->headers_out->set("Last-Modified" => time());
	   				  $f->r->headers_out->set("Cache-control"=>"max-age=0");
	   				  $f->r->headers_out->set("Content-Length"=>$filesize);
					  $f->r->content_type($content_type);
					  open (FH,"$imagefile") or die ("couldn't open $imagefile\n");
 							read (FH,$image2,$filesize) ;
 					  close FH;

					  $f->print($image2);				  
					  $return_value=Apache2::Const::OK;
				  }
	  }
      return $return_value;
      
} 

  1; 
=head1 NAME

Apache2::AMFImageRendering - Used to resize images on the fly to adapt to the screen size of the mobile device

=head1 DESCRIPTION

This module have the scope to manage with WURFLFilter.pm or WURFLFilterMemcached.pm module the images for mobile devices. 

For more details: http://www.idelfuschini.it/apache-mobile-filter-v2x.html


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
