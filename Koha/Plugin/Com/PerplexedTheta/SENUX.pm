package Koha::Plugin::Com::PerplexedTheta::SENUX;

use Modern::Perl;

use base qw{ Koha::Plugins::Base };

use Koha::Libraries;
use Koha::AdditionalContents;
use Koha::DateUtils qw{ dt_from_string };
use Koha::Config::SysPrefs;

use Cwd         qw( abs_path );
use File::Which qw{ which };
use JSON;
use JSON::Validator::Schema::OpenAPIv2;
use POSIX qw{ strftime };

our $VERSION  = '25.11.01';
our $metadata = {
    name            => 'SENUX',
    author          => 'Jake Deery',
    date_authored   => '2025-04-11',
    date_updated    => '2026-07-23',
    minimum_version => '25.11.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'SENUX is a custom OPAC theme, built with Bootstrap. See README.md for customisations.',
    repo            => 'https://github.com/openfifth/koha-plugin-senux',
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);
    $self->{'cgi'} = CGI->new();

    return $self;
}

sub install {
    my ($self) = @_;

    return undef
        unless ( $self->npm_new );

    $self->store_data(
        {
            compile_count => 0,
            date_updated  => strftime( "%Y-%m-%d %H:%M:%S", localtime ),
        }
    );

    return 1;
}

sub upgrade {
    my ($self) = @_;

    return undef
        unless ( $self->npm_reinstall( { confirm => 'yes_please' } ) );

    $self->store_data( { date_updated  => strftime( "%Y-%m-%d %H:%M:%S", localtime ) } );

    return 1;
}

sub uninstall {
    my ($self) = @_;

    return undef
        unless ( $self->npm_delete( { all => 1 } ) );

    return 1;
}

sub npm_new {
    my ( $self, $args ) = @_;

    return undef
        unless ( $self->_chdir( { path => abs_path( $self->mbf_dir ) . '/static_files' } ) );

    my $install = `bash -- ./manage_senux.sh --install 2>&1`;
    return $self->_throw_error(
        {
            message     => '`bash -- ./manage_senux.sh --install` failed to run',
            output      => $install,
            return_code => $?,
        }
    ) unless ( $? == 0 );

    return 1;
}

sub npm_reinstall {
    my ( $self, $args ) = @_;

    return undef
        unless ( defined $args && $args->{'confirm'} eq 'yes_please' );

    return undef
        unless ( $self->_chdir( { path => abs_path( $self->mbf_dir ) . '/static_files' } ) );

    my $reinstall = `bash -- ./manage_senux.sh --reinstall 2>&1`;
    return $self->_throw_error(
        {
            message     => '`bash -- ./manage_senux.sh --reinstall` failed to run',
            output      => $reinstall,
            return_code => $?,
        }
    ) unless ( $? == 0 );

    return 1;
}

sub npm_reset {
    my ( $self, $args ) = @_;

    return undef
        unless ( defined $args && $args->{'confirm'} eq 'yes_please' );

    return undef
        unless ( $self->_chdir( { path => abs_path( $self->mbf_dir ) . '/static_files' } ) );

    my $all = $args->{'all'} ? $args->{'all'} : undef;

    my $reset;
    if ( $all ) {
        $reset = `bash -- ./manage_senux.sh --reset-all 2>&1`;
    } else {
        $reset = `bash -- ./manage_senux.sh --reset 2>&1`;
    }

    return $self->_throw_error(
        {
            message     => '`bash -- ./manage_senux.sh --reset' . ($all) ? '-all' : '' . '` failed to run',
            output      => $reset,
            return_code => $?,
        }
    ) unless ( $? == 0 );

    return 1;
}

sub npm_build {
    my ( $self, $args ) = @_;

    return undef
        unless ( $self->_chdir( { path => abs_path( $self->mbf_dir ) . '/static_files' } ) );

    my $build_type = $args->{'build_type'} || 'all';

    my $build;
    if ( $build_type eq 'sass' ) {
        $build = `bash -- ./manage_senux.sh --build-sass 2>&1`;
    } elsif ( $build_type eq 'js' ) {
        $build = `bash -- ./manage_senux.sh --build-js 2>&1`;
    } else {
        $build = `bash -- ./manage_senux.sh --build-all 2>&1`;
    }

    return $self->_throw_error(
        {
            message     => '`bash -- ./manage_senux.sh --build-' . $build_type . '` failed to run',
            output      => $build,
            return_code => $?,
        }
    ) unless ( $? == 0 );

    $self->_increment_compile_count;
    $self->_increment_date_updated;

    return 1;
}

sub npm_delete {
    my ( $self, $args ) = @_;

    return undef
        unless ( $self->_chdir( { path => abs_path( $self->mbf_dir ) . '/static_files' } ) );

    my $all = $args->{'all'} ? $args->{'all'} : undef;

    my $delete;
    unless ( $all ) {
        $delete = `bash -- ./manage_senux.sh --delete 2>&1`;
    } else {
        $delete = `bash -- ./manage_senux.sh --delete-all 2>&1`;
    }

    return $self->_throw_error(
        {
            message     => '`bash -- ./manage_senux.sh --delete' . ($all) ? '-all' : '' . '` failed to run',
            output      => $delete,
            return_code => $?,
        }
    ) unless ( $? == 0 );

    return 1;
}

sub load_html_customisations {
    my ( $self, $args ) = @_;
    my $html_path = abs_path( $self->mbf_dir ) . '/static_files/src/html';

    my @html_customisations = (
        {
            location  => 'opaccredits',
            title     => 'SENUX_opaccredits',
            file_path => $html_path . '/OPACCredits.sample.html',
        },
        {
            location  => 'opacheader',
            title     => 'SENUX_opacheader',
            file_path => $html_path . '/OPACHeader.sample.html',
        },
        {
            location  => 'OpacLoginInstructions',
            title     => 'SENUX_OpacLoginInstructions',
            file_path => $html_path . '/OPACLoginInstructions.sample.html',
        },
        {
            location  => 'OpacMaintenanceNotice',
            title     => 'SENUX_OpacMaintenanceNotice',
            file_path => $html_path . '/OPACMaintenanceNotice.sample.html',
        },
        {
            location  => 'OpacMaintenanceNotice',
            title     => 'SENUX_OpacMaintenanceNotice',
            file_path => $html_path . '/OPACMaintenanceNotice.sample.html',
        },
        {
            location  => 'OpacMainUserBlock',
            title     => 'SENUX_OpacMainUserBlock',
            file_path => $html_path . '/OPACMainUserBlock.sample.html',
        },
        {
            location  => 'OpacMySummaryNote',
            title     => 'SENUX_OpacMySummaryNote',
            file_path => $html_path . '/OPACMySummaryNote.sample.html',
        },
        {
            location  => 'OpacNavBottom',
            title     => 'SENUX_OpacNavBottom',
            file_path => $html_path . '/OPACNavBottom.sample.html',
        },
        {
            location  => 'OpacNavRight',
            title     => 'SENUX_OpacNavRight',
            file_path => $html_path . '/OPACNavRight.sample.html',
        },
        {
            location  => 'PatronSelfRegistrationAdditionalInstructions',
            title     => 'SENUX_PatronSelfRegistrationAdditionalInstructions',
            file_path => $html_path . '/PatronSelfRegistrationAdditionalInstructions.sample.html',
        },
    );

    for my $html_customisation (@html_customisations) {
        unless (
            $self->_check_html_customisation(
                { location => $html_customisation->{'location'}, title => $html_customisation->{'title'} }
            )
            )
        {
            my $set_customisation = $self->_set_html_customisation(
                {
                    location => $html_customisation->{'location'},
                    title    => $html_customisation->{'title'},
                    content  => $self->_load_text_file( { filename => $html_customisation->{'file_path'} } ),
                }
            );
            return $self->_throw_error(
                {
                    message     => 'failed to load html customisation ' . $html_customisation->{'location'},
                    return_code => 0,
                }
            ) unless defined $set_customisation;
        }
    }

    my @sys_prefs = (
        {
            variable  => 'OPACSearchForTitleIn',
            type      => 'textarea',
            file_path => $html_path . '/OPACSearchForTitleIn.sample.html',
        },
    );

    for my $sys_pref (@sys_prefs) {
        my $set_sys_pref = $self->_set_sys_pref(
            {
                variable => $sys_pref->{'variable'},
                value    => $self->_load_text_file( { filename => $sys_pref->{'file_path'} } ),
            }
        );
        return $self->_throw_error(
            {
                message     => 'failed to set syspref ' . $sys_pref->{'variable'},
                return_code => 0,
            }
        ) unless defined $set_sys_pref;
    }

    return 1;
}

sub configure {
    my ($self) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template( { file => 'configure.tt' } );

    $template->param(
        IS_ENABLED    => $self->is_enabled,
        METADATA      => $self->{'metadata'},
        COMPILE_COUNT => $self->_get_compile_count,
        DATE_UPDATED  => $self->_get_date_updated,
    );

    $self->output_html( $template->output() );
}

sub load_text_file {
    my ( $self, $filename ) = @_;

    return $self->_throw_error(
        {
            message     => 'filename not passed as argument',
            return_code => 0,
        }
    ) unless defined $filename;

    return $self->_load_text_file(
        {
            filename => $filename,
        }
    );
}

sub save_text_file {
    my ( $self, $filename, $content ) = @_;

    return $self->_throw_error(
        {
            message     => 'filename not passed as argument',
            return_code => 0,
        }
    ) unless defined $filename;

    return $self->_throw_error(
        {
            message     => 'content not passed as argument',
            return_code => 0,
        }
    ) unless defined $content;

    return $self->_save_text_file(
        {
            filename => $filename,
            content  => $content,
        }
    );
}

sub api_routes {
    my ($self) = @_;

    my $spec_file = $self->mbf_path('openapi.yaml');
    my $schema    = JSON::Validator::Schema::OpenAPIv2->new->resolve($spec_file);
    my $spec      = $schema->bundle->data;

    return $spec;
}

sub api_namespace {
    my ($self) = @_;

    return 'senux';
}

sub static_routes {
    my ($self) = @_;

    my $spec_file = $self->mbf_path('staticapi.yaml');
    my $schema    = JSON::Validator::Schema::OpenAPIv2->new->resolve($spec_file);
    my $spec      = $schema->bundle->data;

    return $spec;
}

sub opac_head {
    my ($self) = @_;
    my $version = $self->_get_compile_count;

    return
        '<link rel="stylesheet" href="/api/v1/contrib/senux/static/static_files/dist/senux.min.css?version='
        . $version . '" />';
}

sub opac_js {
    my ($self) = @_;
    my $version = $self->_get_compile_count;

    return '<script src="/api/v1/contrib/senux/static/static_files/dist/senux.min.js?version=' . $version
        . '"></script>';
}

sub _chdir {
    my ( $self, $args ) = @_;

    my $chdir = chdir $args->{'path'};
    unless ($chdir) {
        $self->_throw_error(
            {
                message     => 'could not cd to ' . $args->{'path'},
                return_code => $chdir,
            }
        );

        return undef;
    }

    return 1;
}

sub _check_html_customisation {
    my ( $self, $args ) = @_;
    my $location = $args->{'location'};
    my $title    = $args->{'title'};

    my $additional_contents = Koha::AdditionalContents->search();
    return undef
        unless $additional_contents;

    while ( my $additional_content = $additional_contents->next ) {
        my $translated_contents = $additional_content->translated_contents;
        return undef
            unless $translated_contents;

        while ( my $translated_content = $translated_contents->next ) {
            return 1
                if $additional_content->location eq $location
                and $translated_content->title eq $title;
        }
    }

    return undef;
}

sub _set_html_customisation {
    my ( $self, $args ) = @_;
    my $location = $args->{'location'};
    my $title    = $args->{'title'};
    my $content  = $args->{'content'};

    my $additional_content = Koha::AdditionalContent->new(
        {
            category     => 'html_customizations',
            code         => '',
            location     => $location,
            branchcode   => undef,
            published_on => dt_from_string,
        }
    )->store;
    return undef
        unless $additional_content;

    $additional_content->translated_contents(
        [
            {
                lang    => 'default',
                title   => $title,
                content => $content,
            }
        ]
    ) or return undef;

    $additional_content->discard_changes;

    return 1;
}

sub _set_sys_pref {
    my ( $self, $args ) = @_;
    my $variable      = lc $args->{'variable'};
    my $variable_case = $args->{'variable'};
    my $value         = $args->{'value'};
    my $type          = $args->{'type'};

    my $sys_pref = Koha::Config::SysPrefs->find($variable);

    if ($sys_pref) {
        $sys_pref->set(
            {
                variable => $variable,
                value    => $value,
            },
        )->store or return undef;
        $sys_pref->discard_changes;
    } else {
        $sys_pref = Koha::Config::SysPref->new(
            {
                variable    => $variable_case,
                value       => $value,
                explanation => undef,
                type        => $type,
                options     => undef,
            }
        )->store();
    }

    return 1;
}

sub _load_text_file {
    my ( $self, $args ) = @_;
    my $filename = $args->{'filename'};

    unless ( -f $filename ) {
        $self->_throw_error(
            {
                message     => $args->{'filename'} . ' does not exist',
                return_code => 0,
            }
        );

        return undef;
    }

    open my $fh, '<', $filename;

    unless ( defined $fh ) {
        $self->_throw_error(
            {
                message     => 'could not create filehandle',
                return_code => $?,
            }
        );

        return undef;
    }

    chomp( my @lines = <$fh> );

    close $fh;

    return join "\n", @lines;
}

sub _save_text_file {
    my ( $self, $args ) = @_;
    my $filename = $args->{'filename'};
    my $content  = $args->{'content'};

    open my $fh, '>', $filename;

    unless ( defined $fh ) {
        $self->_throw_error(
            {
                message     => 'could not create filehandle',
                return_code => $?,
            }
        );

        return undef;
    }

    print $fh $content;

    close $fh;

    return 1;
}

sub _get_compile_count {
    my ( $self, $args ) = @_;

    return $self->retrieve_data('compile_count') || 0;
}

sub _get_date_updated {
    my ( $self, $args ) = @_;

    return $self->retrieve_data('date_updated') || '0000-00-00 00:00:00';
}

sub _increment_compile_count {
    my ( $self, $args ) = @_;
    my $compile_count = $self->_get_compile_count;

    return $self->store_data( { compile_count => ++$compile_count } );
}

sub _increment_date_updated {
    my ( $self, $args ) = @_;

    return $self->store_data( { date_updated => strftime( "%Y-%m-%d %H:%M:%S", localtime ) } );
}

sub _throw_error {
    my ( $self, $args ) = @_;
    my $json = JSON->new->allow_nonref;

    warn $json->encode($args);

    die
        if defined $self->{'_die'};

    return undef;
}

1;
