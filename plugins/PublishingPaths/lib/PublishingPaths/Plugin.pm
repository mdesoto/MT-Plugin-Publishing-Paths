# Copyright 2010 Michael De Soto. This program is distributed under the 
# terms of the GNU General Public License.

package PublishingPaths::Plugin;

use strict;
use warnings;

## Monkeypatch
sub init_app {
    *MT::Blog::site_url = \&site_url;
}


# Handle altering the general configuration screen. Basically
# we prevent changing path information from this screen now.
sub cfg_prefs_hdlr {
    my ($cb, $app, $tmpl) = @_;

    if (my $blog = $app->blog) {
    
        if (MT->version_number > 5) {

            my $site_url = $blog->site_url;
            $$tmpl =~ s/<mt:var name="website_scheme">:\/\///gi;
            $$tmpl =~ s/<mt:var name="website_domain">/$site_url/gi;
            $$tmpl =~ s/<div class="hint"><__trans phrase="The URL of your .*<\/div>//gi;
            $$tmpl =~ s/<span class="extra-path">.*<\/span>//gi;
            
            my $site_path = $blog->site_path;
            $$tmpl =~ s/<mt:var name="website_path">/$site_path/gi;
            $$tmpl =~ s/<input type="text" name="site_path".*\/>/<div class="hint"><__trans phrase="This blog's publishing paths are now managed by the"> <a href="<mt:var name="SCRIPT_URL">?__mode=cfg_plugins&amp;blog_id=<mt:var name="BLOG_ID" escape="html">">Publishing Paths<\/a> plugin.<\/div>/gi;
            $$tmpl =~ s/<div class="hint"><__trans phrase="The path where your index files will be published.*<\/div>//gi;
            $$tmpl =~ s/<input type="checkbox" name="enable_archive_paths".*<\/label>//gi;

        }
    }
}


# Handle adding the custom background to the body tag. Soon will also include
# dropdown in header to enable fast switching between environments.
sub header_hdlr {
    my ($cb, $app, $tmpl) = @_;
    
    if (my $blog = $app->blog) {

        my $scope = 'blog:' . $blog->id;
        my $plugin = MT->component('PublishingPaths');

        my $pdata = $plugin->get_config_obj($scope);
        my $data = $pdata->data;

        # Display the current environment in the background 
        # so it's clear what context we're in.
        if ($data->{'pp_bg'}) {

            my $environment = $data->{'pp_env'};
            if (MT->version_number > 5) {

                my $style = <<NEW;
<style type="text/css">
    body {
        background: url('<\$mt:var name="static_uri"\$>plugins/PublishingPaths/img/background-$environment.png') repeat;
    }
</style>
NEW

                $$tmpl =~ s/(<\/head>)/$style$1/gi;

            } elsif (MT->version_number > 4) {

                my $style = <<NEW;
<style type="text/css">
    #content-header {
        background: #e7f0f6 url('<\$mt:var name="static_uri"\$>plugins/PublishingPaths/img/background-$environment.png') repeat;
    }
</style>
NEW

                $$tmpl =~ s/(<\/head>)/$style$1/gi;
            }
        }

        # Add a dropdown to the menu to allow switching between environments.
        my $old = <<OLD;
        </div>
            </div><!-- /menu-bar -->
OLD

        my $new = <<NEW;
    <mt:if name="blog_id">
        <mt:if name="compose_menus">
                    <div id="<mt:var name="scope_type">-fav-actions-nav" class="fav-actions-nav">
                        <ul>
                        <mt:loop name="compose_menus">
                            <mt:loop name="menus">
            <mt:if name="__first__">
                            <li>
                                <em>
                                    <a href="<mt:var name="link">" class="fav-actions-root-link">
                                        <span class="<mt:var name="root_class">"><mt:var name="root_label"></span>
                                    </a>
                                </em>
                                <div id="fav-actions" class="fav-actions hidden">
                                <ul>
            </mt:if>
                                    <li><a href="<mt:var name="link">"><span class="action-label"><mt:var name="label"></span></a></li>
            <mt:if name="__last__">
                                </ul>
                                </div>
                            </li>
            </mt:if>
                            </mt:loop>
                        </mt:loop>
                        </ul>
                    </div>
        </mt:if>
    </mt:if>
NEW

#        $$tmpl =~ s/($old)/$new$1/gi
    }
}


# Swap out blog's path information after plugin saved.
sub post_save {
    my ($cb, $pdata) = @_;
    
    my $scope = $pdata->key;
    $scope =~ s/.*:([\d]+)$/$1/;

    if (my $blog = MT::Blog->lookup($scope)) {

        my $data = $pdata->data;
        my $env = 'pp_'.$data->{'pp_env'};

        if ($data->{$env.'_path'} || $data->{$env.'_url'}) {
            $blog->site_path($data->{$env.'_path'});
            $blog->site_url($data->{$env.'_url'});
            $blog->save;
        }

# require Data::Dumper;
# require MT::Log;
# MT->log({message => Data::Dumper::Dumper($blog)});
    }
}


# We want to stash the original MT path settings here so that we can safely 
# overwrite them in the future. Check if any prior settings have been saved. 
# If not, save the original path as this plugin's production path.
sub pre_run {
    my ($cb, $app) = @_;

    if (my $blog = $app->blog) {

        my $scope = 'blog:' . $blog->id;
        my $plugin = MT->component('PublishingPaths');

        my $pdata = $plugin->get_config_obj($scope);
        my $data = $pdata->data;

        unless ($data->{'pp_prod_path'} && $data->{'pp_prod_url'}) {

            $data->{'pp_prod_path'} = $blog->site_path;
            $data->{'pp_prod_url'} = $blog->site_url;
            $plugin->save_config($data, $scope);
        }
    }
}

# This method is identical to MT's site_url function EXCEPT that we now 
# account for cases when the blog's URL is outside of the website path.
sub site_url {
    my $blog = shift;
    
    if (MT->version_number > 5) {

        if (@_) {
            return $blog->column('site_url', @_);
        } elsif ( $blog->is_dynamic ) {
            my $cfg = MT->config;
            my $path = $cfg->CGIPath;
            if ($path =~ m!^/!) {
                # relative path, prepend blog domain
                my ($blog_domain) = $blog->archive_url =~ m|(.+://[^/]+)|;
                $path = $blog_domain . $path;
            }
            $path .= '/' unless $path =~ m{/$};
            return $path;
        } else {
            my $url = '';
            if ($blog->is_blog()) {
            
                ## MT uses the parent blog, or website, to determine the URL and
                ## path. The Publishing Paths plugin breaks this by potientially 
                ## moving both the URL and the path outside the website root. So,
                ## we do a quick check here to see if we have an FQDN on the blog,
                ## before attempting to build the URL. No need to build if we
                ## already have it.
                return $blog->column('site_url') if ($blog->column('site_url') =~ m!^https?://!);
                
                ## Otherwise, we let MT to continue to do its thing.
                if (my $website = $blog->website()) {
                    $url = $website->column('site_url');

                }
                else {
                    # FIXME: there are a few occasions where
                    # a blog does not have its parent, like (bugid:102749)
                    return $blog->column('site_url');
                }
                my @paths = $blog->raw_site_url;
                if ( 2 == @paths ) {
                    if ( $paths[0] ) {
                        $url =~ s!^(https?)://(.+)/$!$1://$paths[0]$2/!;
                    }
                    if ( $paths[1] ) {
                        $url = MT::Util::caturl( $url, $paths[1] );
                    }
                }
                else {
                    $url = MT::Util::caturl( $url, $paths[0] );
                }
            }
            else {
                $url = $blog->column('site_url');
            }

            return $url;
        }

    } elsif (MT->version_number > 4) {

        if (!@_ && $blog->is_dynamic) {
            my $cfg = MT->config;
            my $path = $cfg->CGIPath;
            $path .= '/' unless $path =~ m!/$!;
            return $path . $cfg->ViewScript . '/' . $blog->id;
        } else {
            return $blog->column('site_url', @_);
        }

    }
}


1;