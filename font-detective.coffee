
# Helpers
after = (ms, fn)-> tid = setTimeout fn, ms; stop: -> clearTimeout tid
every = (ms, fn)-> iid = setInterval fn, ms; stop: -> clearInterval iid


do (exports = window)->
	
	# Namespace
	FD = exports.FontDetective = {}
	
	# Configuration
	FD.swf = "./flash/FontList.swf"
	
	# The generic font families defined by CSS
	genericFontFamilies = [
		'serif' # (e.g., Times)
		'sans-serif' # (e.g., Helvetica)
		'cursive' # (e.g., Zapf-Chancery)
		'fantasy' # (e.g., Western)
		'monospace' # (e.g., Courier)
	]
	
	# A list of common fonts, somewhat biased towards Windows
	# @TODO: fallback to checking common font names when flash is unavailable
	someCommonFontNames =
		"Helvetica,Lucida Grande,Lucida Sans,Tahoma,Arial,Geneva,Monaco,Verdana,Microsoft Sans Serif,Trebuchet MS,Courier New,Times New Roman,Courier,Lucida Bright,Lucida Sans Typewriter,URW Chancery L,Comic Sans MS,Georgia,Palatino Linotype,Lucida Sans Unicode,Times,Century Schoolbook L,URW Gothic L,Franklin Gothic Medium,Lucida Console,Impact,URW Bookman L,Helvetica Neue,Nimbus Sans L,URW Palladio L,Nimbus Mono L,Nimbus Roman No9 L,Arial Black,Sylfaen,MV Boli,Estrangelo Edessa,Tunga,Gautami,Raavi,Mangal,Shruti,Latha,Kartika,Vrinda,Arial Narrow,Century Gothic,Garamond,Book Antiqua,Bookman Old Style,Calibri,Cambria,Candara,Corbel,Monotype Corsiva,Cambria Math,Consolas,Constantia,MS Reference Sans Serif,MS Mincho,Segoe UI,Arial Unicode MS,Tempus Sans ITC,Kristen ITC,Mistral,Meiryo UI,Juice ITC,Papyrus,Bradley Hand ITC,French Script MT,Malgun Gothic,Microsoft YaHei,Gisha,Leelawadee,Microsoft JhengHei,Haettenschweiler,Microsoft Himalaya,Microsoft Uighur,MoolBoran,Jokerman,DFKai-SB,KaiTi,SimSun-ExtB,Freestyle Script,Vivaldi,FangSong,MingLiU-ExtB,MingLiU_HKSCS,MingLiU_HKSCS-ExtB,PMingLiU-ExtB,Copperplate Gothic Light,Copperplate Gothic Bold,Franklin Gothic Book,Maiandra GD,Perpetua,Eras Demi ITC,Felix Titling,Franklin Gothic Demi,Pristina,Edwardian Script ITC,OCR A Extended,Engravers MT,Eras Light ITC,Franklin Gothic Medium Cond,Rockwell Extra Bold,Rockwell,Curlz MT,Blackadder ITC,Franklin Gothic Heavy,Franklin Gothic Demi Cond,Lucida Handwriting,Segoe UI Light,Segoe UI Semibold,Lucida Calligraphy,Cooper Black,Viner Hand ITC,Britannic Bold,Wide Latin,Old English Text MT,Broadway,Footlight MT Light,Harrington,Snap ITC,Onyx,Playbill,Bauhaus 93,Baskerville Old Face,Algerian,Matura MT Script Capitals,Stencil,Batang,Chiller,Harlow Solid Italic,Kunstler Script,Bernard MT Condensed,Informal Roman,Vladimir Script,Bell MT,Colonna MT,High Tower Text,Californian FB,Ravie,Segoe Script,Brush Script MT,SimSun,Arial Rounded MT Bold,Berlin Sans FB,Centaur,Niagara Solid,Showcard Gothic,Niagara Engraved,Segoe Print,Gabriola,Gill Sans MT,Iskoola Pota,Calisto MT,Script MT Bold,Century Schoolbook,Berlin Sans FB Demi,Magneto,Arabic Typesetting,DaunPenh,Mongolian Baiti,DokChampa,Euphemia,Kalinga,Microsoft Yi Baiti,Nyala,Bodoni MT Poster Compressed,Goudy Old Style,Imprint MT Shadow,Gill Sans MT Condensed,Gill Sans Ultra Bold,Palace Script MT,Lucida Fax,Gill Sans MT Ext Condensed Bold,Goudy Stout,Eras Medium ITC,Rage Italic,Rockwell Condensed,Castellar,Eras Bold ITC,Forte,Gill Sans Ultra Bold Condensed,Perpetua Titling MT,Agency FB,Tw Cen MT,Gigi,Tw Cen MT Condensed,Aparajita,Gloucester MT Extra Condensed,Tw Cen MT Condensed Extra Bold,PMingLiU,Bodoni MT,Bodoni MT Black,Bodoni MT Condensed,MS Gothic,GulimChe,MS UI Gothic,MS PGothic,Gulim,MS PMincho,BatangChe,Dotum,DotumChe,Gungsuh,GungsuhChe,MingLiU,NSimSun,SimHei,DejaVu Sans,DejaVu Sans Condensed,DejaVu Sans Mono,DejaVu Serif,DejaVu Serif Condensed,Eurostile,Matisse ITC,Bitstream Vera Sans Mono,Bitstream Vera Sans,Staccato222 BT,Bitstream Vera Serif,Broadway BT,ParkAvenue BT,Square721 BT,Calligraph421 BT,MisterEarl BT,Cataneo BT,Ruach LET,Rage Italic LET,La Bamba LET,Blackletter686 BT,John Handy LET,Scruff LET,Westwood LET"
			.split(",")
	
	
	FD.testedFonts = []
	
	
	# The container for all font-detective related uglyness
	container = document.createElement "div"
	container.id = "font-detective"
	# The document body won't always exist at this point, so append this later
	
	# An element whose only purpose is to be replaced (how sad)
	dummy = document.createElement "div"
	dummy.id = "font-detective-dummy"
	container.appendChild dummy
	
	# The ID of the flash <object>
	swfId = "font-detective-flash"
	
	
	###
	# The font.name property can be used to display the name of the font
	# 
	# The font can be stringified and will be escaped for use in css
	# e.g. font.toString() or (font + ", sans-serif")
	###
	class Font
		constructor: (@name, @type, @style)->
		toString: ->
			# Escape \ to \\ then " to \" and surround with quotes
			'"' + @name.replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + '"'
	
	# http://www.dustindiaz.com/smallest-domready-ever
	domReady = (callback)->
		if /in/.test document.readyState
			after 10, -> domReady callback
		else
			callback()
	
	# Based off of http://www.lalit.org/lab/javascript-css-font-detect
	fontAvailabilityChecker = do ->
		
		# A font will be compared against three base fonts
		# If it differs from one of the base measurements
		# (which implies it didn't fall back to the base font), then the font is available
		baseFontFamilies = ["monospace", "sans-serif", "serif"]
		
		# We use m or w because they take up the maximum width
		# We use thin letters so that some matching fonts can get separated
		testString = "mmmmmmmmmmlli"
		# This seems to work just as well with the empty string, though
		
		# We test using 72px font size; it doesn't matter much
		testSize = "72px"
		
		# Create a span in the document to get the width of the text we use to test
		span = document.createElement "span"
		span.innerHTML = testString
		span.style.fontSize = testSize
		baseWidths = {}
		baseHeights = {}
		
		init: ->
			# Call this method once the document has a body
			document.body.appendChild container
			
			for baseFontFamily in baseFontFamilies
				# Get the dimensions of the three base fonts
				span.style.fontFamily = baseFontFamily
				container.appendChild span
				baseWidths[baseFontFamily] = span.offsetWidth
				baseHeights[baseFontFamily] = span.offsetHeight
				container.removeChild span
		
		check: (font)->
			# Check whether a font is available
			for baseFontFamily in baseFontFamilies
				span.style.fontFamily = "#{font}, #{baseFontFamily}"
				container.appendChild span
				differs = (
					span.offsetWidth isnt baseWidths[baseFontFamily] or
					span.offsetHeight isnt baseHeights[baseFontFamily]
				)
				container.removeChild span
				
				return yes if differs
			return no
	
	loadedSWF = null
	loadSWF = (cb)->
		
		domReady ->
			
			if loadedSWF
				return cb null, loadedSWF
			
			flashvars = swfObjectId: swfId
			params = allowScriptAccess: "always", menu: "false"
			attributes = id: swfId, name: swfId
			
			swfCallback = (e)->
				if e.success
					cb null, loadedSWF = e.ref
				else
					cb new Error "Failed to load the SWF Object"
			
			document.body.appendChild container
			
			# That is one dubious function signature
			swfobject.embedSWF(
				FD.swf # specifies the URL of the SWF file
				dummy.id # specifies the id of the element to be replaced by the Flash content
				"1", "1" # width and height specify the dimensions of the SWF
				"9.0.0" # version specifies the Flash player version the SWF is published for
				no # (optional) specifies the URL of an express install SWF and activates Adobe express install
				flashvars # generates a <param name="flashvars" value="...">
				params # generates <param> elements (nested within the <object> element)
				attributes # sets attributes on the <object> element
				swfCallback # (SWFObject 2.2+) a callback function that is called on both success or failure
			)
	
	consumeFontDefinitions = (fontDefinitions)->
		
		fontAvailabilityChecker.init()
		
		for {fontName, fontType, fontStyle} in fontDefinitions
			font = new Font fontName, fontType, fontStyle
			# @TODO: avoid lag by testing in chunks
			available = fontAvailabilityChecker.check font
			if available
				FD.testedFonts.push font
				for callback in FD.each.callbacks
					callback font
		
		for callback in FD.all.callbacks
			callback FD.testedFonts
		
		FD.all.callbacks = []
		FD.each.callbacks = []
	
	
	###
	# FontDetective.each(function(font){})
	# Calls back with a `Font` every time a font is detected and tested
	###
	FD.each = (callback)->
		
		callback font for font in FD.testedFonts
		
		FD.each.callbacks.push callback
		
	FD.each.callbacks = []
	
	
	###
	# FontDetective.all(function(fonts){})
	# Calls back with an `Array` of `Font`s when all fonts are detected and tested
	###
	FD.all = (callback)->
		
		FD.all.callbacks.push callback
		
	FD.all.callbacks = []
	
	
	
	###
	# FontDetective.load()
	# Load the SWF object and start detecting fonts
	###
	FD.load = (cb)->
		
		fail = (message)->
			err = new Error message
			if cb
				cb err
			else
				throw err
		
		warn = (message)->
			if console?.warn
				console.warn message
			else if console?.log
				console.log message
		
		loadSWF (err, swf)->
			if err
				fail "Failed to load SWF Object"
			else
				
				# @TODO: avoid timeouts and intervals
				timeout = after 2000, ->
					
					unsupported = ""
					if location.protocol is "file:"
						warn unsupported = "
							FontDetective doesn't work from the file: protocol.
							Start up a webserver, e.g. with python -m SimpleHTTPServer
						"
					else
						warn "This is taking a while... :("
					
					timeout = after 2000, ->
						interval?.stop()
						return fail "
							Couldn't connect with flash interface.
							Timed out waiting for the SWF to expose an external method.
							#{unsupported}
						"
				
				interval = every 50, ->
					if swf.fonts
						interval?.stop()
						timeout?.stop()
						consumeFontDefinitions swf.fonts()
