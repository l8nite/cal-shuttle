
function Response( oData )
{
	if( !oData || typeof(oData) != 'object' )
	{
		return null;
	}

	this._dom = oData;
	this.root = oData.documentElement;
}


Response.prototype.GetRoot = function()
{
	return this.root;
}

Response.prototype.GetCode = function()
{
	return this.root.getAttribute('ResultCode');
}


Response.prototype.GetText = function()
{
	return this.root.getAttribute('ResultString');
}

