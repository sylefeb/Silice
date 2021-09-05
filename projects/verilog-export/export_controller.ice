// we indicate that we want the controller synthesized for the ULX3S
// this is normally done by the framework, but for export we use
// the empty 'bare' framework
$$ULX3S = 1 
// we include the controller and required interfaces
$include('../common/sdram_interfaces.ice')
$include('../common/sdram_controller_autoprecharge_r16_w16.ice')
