# Copyright 2010 Michael De Soto. This program is distributed under the 
# terms of the GNU General Public License. Consult LICENSE for more information.

package PublishingPaths::Plugin;

use strict;
use warnings;

use MT::Util qw/ trim /;

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

1;