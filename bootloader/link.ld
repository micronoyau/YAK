OUTPUT_FORMAT("binary")
SECTIONS
{
    . = 0x7e00;
    .boot : {
        /* code = .; */
        *(.boot)
        *(.text)
        *(.data)
        *(.bss)
        /* . = ALIGN(4096); */
      }

      /* Stuff added by gcc */
      /DISCARD/ : {
          *(.eh_frame)
          *(.note.gnu.property)
      }
}
