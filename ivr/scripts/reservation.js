/*
  A class to represent a cal-shuttle reservation
*/

function Reservation()
{
	this._ID = null;
	this._Airport = null;
	this._FlightDate = null;
	this._FlightTime = null;
	this._PickupDate = null;
	this._PickupTime = null;
	this._Fare = null;
	this._UID = null;
}


/*
  Accessor/Mutators for the data members of this class
*/
Reservation.prototype.GetID = function()
{
	return this._ID;
}

Reservation.prototype.SetID = function( ID )
{
	this._ID = ID;
}

Reservation.prototype.GetUID = function()
{
	return this._UID;
}

Reservation.prototype.SetUID = function( UID )
{
	this._UID = UID;
}

Reservation.prototype.GetAirport = function()
{
	return this._Airport;
}

Reservation.prototype.SetAirport = function( Airport )
{
	this._Airport = Airport;
}


Reservation.prototype.GetFlightDate = function()
{
	var t = this._FlightDate;
	var m = t.getMonth() + 1;
	var d = t.getDate();
	var y = (t.getYear() % 100);

	// no sprintf...
	if( m <= 9 ) { m = "0" + m; }
	if( d <= 9 ) { d = "0" + d; }
	if( y <= 9 ) { y = "0" + y; }

	return m + '/' + d + '/' + y;
}

Reservation.prototype.SetFlightDate = function( FlightDate )
{
	var now = new Date();

	if( isNaN( FlightDate ) || FlightDate >= 9 )
	{
		// FlightDate is in the format YYYYMMDD with ?'s for unknown
		var year  = FlightDate.substring(0,4);
		var month = FlightDate.substring(4,6);
		var date  = FlightDate.substring(6,8);

		if( year == '????' )
		{
			year = now.getFullYear();
		}

		if( month == '??' )
		{
			month = now.getMonth() + 1;
		}

		if( date == '??' )
		{
			date = now.getDate();
		}

		FlightDate = new Date( year, month-1, date );
	}
	else
	{
		// It's safe to use these because there will never be an 
		// allowable date of 00000006 (there is no month 00)

		// FlightDate == ( 0 .. 6 ) then it's the next closest day 
		// FlightDate == 7, then it's today
		// FlightDate == 8, then it's tomorrow

		if( FlightDate == 7 )
		{
			FlightDate = new Date( now.getFullYear(), now.getMonth(), now.getDate() );
		}
		else if( FlightDate == 8 )
		{
			FlightDate = new Date( now.getFullYear(), now.getMonth(), now.getDate() + 1 );
		}
		else
		{
			var diff = FlightDate - now.getDay();
			if( diff <= 0 ) { diff += 7; }
			FlightDate = new Date( now.getFullYear(), now.getMonth(), now.getDate() + diff );
		}
	}

	this._FlightDate = FlightDate;
}


Reservation.prototype.GetFlightTime = function()
{
	var time = this._FlightTime;
	var hours = time.getHours();
	var mints = time.getMinutes();

	// why doesn't javascript have sprintf ?
	if( hours <= 9 ) { hours = "0" + hours; }
	if( mints <= 9 ) { mints = "0" + mints; }

	return hours + ':' + mints;
}

Reservation.prototype.SetFlightTime = function( FlightTime )
{
	var hour = parseInt(FlightTime.substr(0,2));
	var min  = parseInt(FlightTime.substr(2,4));

	var x  = FlightTime.substr(4,5);

	// convert if we're not military time 
	if( x != '?' && x != 'h' && x == 'p' )
	{
		hour += 12;
	}

	// round down to the nearest 5 minutes
	while( min % 5 != 0 )
	{
		min--;
	}

	FlightTime = new Date( 0, 0, 0, hour, min, 0, 0 );

	this._FlightTime = FlightTime;
}


Reservation.prototype.GetPickupDate = function()
{
	return this._PickupDate;
}

Reservation.prototype.SetPickupDate = function( PickupDate )
{
	this._PickupDate = PickupDate;
}


Reservation.prototype.GetPickupTime = function()
{
	return this._PickupTime;
}

Reservation.prototype.SetPickupTime = function( PickupTime )
{
	this._PickupTime = PickupTime;
}


Reservation.prototype.GetFare = function()
{
	return this._Fare;
}

Reservation.prototype.SetFare = function( Fare )
{
	this._Fare = Fare;
}


