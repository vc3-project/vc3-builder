package VC3::Source::OSNative;
use base 'VC3::Source::Generic';
use Carp;

sub new {
    my ($class, $widget, $json_description) = @_;

    $widget->local(1);

    unless($json_description->{prerequisites}) {

        unless($json_description->{native}) {
            die "No method to verify native OS provided. Add prerequisites or native field.\n";
        }

        $json_description->{prerequisites} = [
            ": check if native is prefix of target",
            'pref=${VC3_MACHINE_TARGET#' . $json_description->{native} . '}',
            '[ $pref != ${VC3_MACHINE_TARGET} ] || exit 1'
        ];
    }

    unless($json_description->{'auto-version'}) {
        $json_description->{'auto-version'} = [
            'echo VC3_VERSION_SYSTEM: $(echo ${VC3_MACHINE_OS} | sed -r -e "s:[^0-9]+([0-9.]+)$:\\1:")'
        ];
    }

    my $self = $class->SUPER::new($widget, $json_description);

    $self->auto_version($json_description->{'auto-version'});

    return $self;
}


sub auto_version {
    my ($self, $new_auto_version) = @_;

    $self->{auto_version} = $new_auto_version if($new_auto_version);

    return $self->{auto_version};
}


1;

