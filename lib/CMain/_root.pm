package CMain::_root;

use Clib::strict8;

##################################################

sub _root :
        Simple
{
    if (rchk('ausweis_list')) {
        #$self->forward('ausweis');
    }
    elsif (rchk('command_info')) {
        #$self->forward('command/my');
    }
    
    return 'default';
}

1;
