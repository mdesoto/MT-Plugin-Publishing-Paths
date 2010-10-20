# Copyright 2010 Michael De Soto. This program is distributed under the 
# terms of the GNU General Public License.

package PublishingPaths::Plugin;

use strict;
use warnings;

sub init_app {
    *MT::Blog::site_url = \&site_url;
}

sub handler {
    my ($cb, %args) = @_;

    my $blog = $args{'blog'};
    my $plugin = MT->component('PublishingPaths');
    
    unless ($blog) {
        if (MT->config->DebugMode > 0) {
            MT->log({message => 'No blog context passed to PublishingPaths::Plugin::handler.'});
        }
        return;
    }

    my $type = 'production';
    $type = 'development' if ($plugin->get_config_value('is_active', 'blog:' . $blog->id));

    my $site_path = $plugin->get_config_value($type . '_site_path', 'blog:' . $blog->id);
    my $site_url = $plugin->get_config_value($type . '_site_url', 'blog:' . $blog->id);

    if ($site_path || $site_url) {
        $blog->site_path($site_path) if ($site_path ne $blog->site_path);
        $blog->site_url($site_url) if ($site_url ne $blog->site_url);
        $blog->save;
    }
}


sub cfg_prefs_hdlr {
    my ($cb, $app, $tmpl) = @_;

    if (my $blog = $app->blog) {
    
        #my $site_url = $blog->{'column_values'}->{'site_url'};
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
        
            my $style = sprintf(
                "<style type=\"text/css\">body { background-image:url('<\$mt:var name=\"static_uri\"\$>plugins/PublishingPaths/img/background-%s.png'); }</style>\n",
                $data->{'pp_env'}
            );
            
            $$tmpl =~ s/(<body id="<\$mt:var name="screen_id"\$>")/$style$1/gi;
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


sub site_url {
    my $blog = shift;

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
}


1;