// Mission Briefing Script by Too Many Cooks

/* <-- Delete these and on line 12 if you want to skip time
// Time Skip for night ops
hint "12 hour flight passes";
[] spawn {
    setTimeMultiplier 720;
    sleep 60;
    setTimeMultiplier 1;
    hint format ["Current time: %1", dayTime];
};
*/

// Put all of your info here - MAKE SURE TO ADD IT TO THE BRIEF SCREEN ALSO
private _title = "<t color='#FF8000' size='3'>Mission Briefing</t>"; // No issues here.
private _paragraph1 = "<t size='1'>Mission. Write Mission Background here, What got us to this moment?</t>";
private _paragraph2 = "<t size='1'>Situation. Write the situation here, What are we doing right now?</t>";
private _paragraph3 = "<t size='1'>Execution. Write Execution here, How are we going to do the mission?</t>";
private _paragraph4 = "<t size='1'>Signal.<br/>Short Ranges<br/>Alpha Team - 101<br/>Bravo Team - 102<br/>Charlie Team - 103<br/>Command Long Range - 50</t>";

// Combine the content into a single formatted text - DO NOT TOUCH
private _briefingText = format [
    "<br/><br/>%1<br/><br/>%2<br/><br/>%3<br/><br/>%4<br/><br/>%5",
    _title,
    _paragraph1,
    _paragraph2,
    _paragraph3,
    _paragraph4
];

titleText [_briefingText, "PLAIN", 1, true, true];
