<?php
function hex_dump($data, $newline="\n")
{
  static $from = '';
  static $to = '';

  static $width = 16; # number of bytes per line

  static $pad = '.'; # padding for non-visible characters

  if ($from==='')
  {
    for ($i=0; $i<=0xFF; $i++)
    {
      $from .= chr($i);
      $to .= ($i >= 0x20 && $i <= 0x7E) ? chr($i) : $pad;
    }
  }

  $hex = str_split(bin2hex($data), $width*2);
  $chars = str_split(strtr($data, $from, $to), $width);

  $offset = 0;
  foreach ($hex as $i => $line)
  {
    echo sprintf('%6X',$offset).' : '.implode(' ', str_split($line,2)) . ' [' . $chars[$i] . ']' . $newline;
    $offset += $width;
  }
}
?>
<?php 
  echo "### Stings\n";
  echo serialize("\"Hello Wörld\"");
  echo "\t";
  echo "Hello Wörld"; 
?>
<?php
  echo serialize([1,2,3, 1.12 => "hi"]);
  // echo var_dump(unserialize("a:3:{s:2:\"11\";i:1;i:1;i:2;i:2;i:3;}"));
?>
<?php 
  echo "\n### Objects\n";
?>
<?php
class A {
    const CONSTANT = "Contant";
    private $aPrivateVar = "private";
    private $aPrivateObj = NULL;   
    public $aPublicVar = "public";
    public $aPublicObj = NULL;
    public $kind = NULL;
   
    function __construct() {
      $a = func_get_args();
      $i = func_num_args();
      if (method_exists($this,$f='__construct'.$i)) {
          call_user_func_array(array($this,$f),$a);
      }
    }
    
    function __construct1($string) {
      $this -> kind = $string;
    }
    
    function aMemberFunc() {
        $this -> aPrivateObj = new A("private");
        $this -> aPublicObj = new A("public");
    }
}

$A = new A;
$A->aMemberFunc();
print base64_encode(serialize($A));
print "\n";
print serialize($A);
?> 
<?php
class PhpClass {
    const CONSTANT = "Contant";
    private $aPrivateVar = "A private\nString";
    public $aPublicVar = "A public String";
}

$PhpClass = new PhpClass;
// hex_dump(serialize($PhpClass));
print base64_encode(serialize($PhpClass));
print "\n";
print serialize($PhpClass);
?> 
