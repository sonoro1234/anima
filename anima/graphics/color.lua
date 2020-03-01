local M = {}

function M.HSV2RGB(H,S,V)

	local var_r, var_g , var_b;
	
	if ( S == 0.0 ) then               --HSV from 0 to 1
		var_r = V;
		var_g = V;
		var_b = V;
	else
		local var_h = H * 6.0;
		if ( var_h == 6.0 ) then var_h = 0.0; end      --H must be < 1
		local var_i = math.floor( var_h );             --Or ... var_i = floor( var_h )
		local var_1 = V * ( 1.0 - S );
		local var_2 = V * ( 1.0 - S * ( var_h - var_i ) );
		local var_3 = V * ( 1.0 - S * ( 1.0 - ( var_h - var_i ) ) );
		
		if      ( var_i == 0 ) then var_r = V     ; var_g = var_3 ; var_b = var_1; 
		elseif ( var_i == 1 ) then var_r = var_2 ; var_g = V     ; var_b = var_1; 
		elseif ( var_i == 2 ) then var_r = var_1 ; var_g = V     ; var_b = var_3; 
		elseif ( var_i == 3 ) then var_r = var_1 ; var_g = var_2 ; var_b = V;     
		elseif ( var_i == 4 ) then var_r = var_3 ; var_g = var_1 ; var_b = V;    
		else                    var_r = V     ; var_g = var_1 ; var_b = var_2; 
		end
	end
	
	return var_r, var_g , var_b
end

return M

