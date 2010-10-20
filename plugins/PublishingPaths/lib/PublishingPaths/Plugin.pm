# Copyright 2010 Michael De Soto. This program is distributed under the 
# terms of the GNU General Public License.

package PublishingPaths::Plugin;

use strict;
use warnings;

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
    
        my $site_url = $blog->{'column_values'}->{'site_url'};
        $$tmpl =~ s/<mt:var name="website_scheme">:\/\///gi;
        $$tmpl =~ s/<mt:var name="website_domain">/$site_url/gi;
        $$tmpl =~ s/<div class="hint"><__trans phrase="The URL of your .*<\/div>//gi;
        $$tmpl =~ s/<span class="extra-path">.*<\/span>//gi;
        
        my $site_path = $blog->{'column_values'}->{'site_path'};
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

1;