package SEL::Indent;
################################################################
#  This package uses a "tie" to allow an integer scalar to
#   represent a string of indentations delimited by the
#   pound (#) character. Good for logging purposes.
################################################################

   use strict;

   sub TIESCALAR {
      ##############################################################################
      # FUNCTION NAME: TIESCALAR()
      #
      # DESCRIPTION:   This function changes the scalar into an object.
      #
      # USAGE:         tie $my_scalar;
      #
      # INPUTS:        none
      #
      # OUTPUTS:       none
      #
      # RETURN VALUE:  reference to the object created.
      #
      # --DATE-- --ECO-- NAME    REVISION HISTORY
      # 20041202         dandw   Created
      ##############################################################################
      my $self = 0;
      bless \$self, shift;
   }

   sub STORE {
      my( $self, $value ) = @_;
      ##############################################################################
      # FUNCTION NAME: STORE()
      #
      # DESCRIPTION:   This function is called on the scalar object by the store function.
      #
      # USAGE:         $my_object->STORE(5);
      #
      # INPUTS:        val - the value to be stored in the object
      #
      # OUTPUTS:       none
      #
      # RETURN VALUE:  none
      #
      # --DATE-- --ECO-- NAME    REVISION HISTORY
      # 20041202         dandw   Created
      ##############################################################################
      if( $value > 0 )
      {
         ++${ $self };
      }
      else
      {
         --${ $self };
      }
      return ${ $self };
   }

   sub FETCH {
      my $counter = ${ my $self = shift };
      ##############################################################################
      # FUNCTION NAME: FETCH()
      #
      # DESCRIPTION:   This function gets the value from an object.
      #
      # USAGE:         $x = my_object->FETCH();
      #
      # INPUTS:        none
      #
      # OUTPUTS:       none
      #
      # RETURN VALUE:  the value stored in the object
      #
      # --DATE-- --ECO-- NAME    REVISION HISTORY
      # 20041202         dandw   Created
      ##############################################################################
      my $str = '';
      while( $counter-- > 0 )
      {
         $str .= '#  ';
      }
      return $str;
   }
1;