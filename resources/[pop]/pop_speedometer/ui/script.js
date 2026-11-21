$(document).ready(function(){
  window.addEventListener("message", function(event) {
    if (event.data.showhud == true) {
      if (!$(".huds").is(":visible"))
        $('.huds').fadeIn();

      setProgressSpeed({speed: event.data.speed, speedUnit: event.data.speedUnit },'.progress-speed');
      setProgressFuel(event.data.fuel,'.progress-fuel');
      setMileage(event.data.mileage);

      const fuelEl = $('.progress-fuel');
      fuelEl.toggleClass('redStroke', event.data.fuel <= 10);
      fuelEl.toggleClass('orangeStroke', event.data.fuel > 10 && event.data.fuel <= 20);
    } else {
      if ($(".huds").is(":visible"))
        $('.huds').fadeOut();
    }
  });

  function setMileage(value){
    $('.mileage-value').text((value || 0).toFixed(1));
  }

  function setProgressFuel(percent, element){
    var circle = document.querySelector(element);
    var radius = circle.r.baseVal.value;
    var circumference = radius * 2 * Math.PI;
    var html = $(element).parent().parent().find('span');

    circle.style.strokeDasharray = `${circumference} ${circumference}`;
    circle.style.strokeDashoffset = `${circumference}`;

    const offset = circumference - ((-percent*73)/100) / 100 * circumference;
    circle.style.strokeDashoffset = -offset;

    html.text(Math.round(percent));
  }

  function setProgressSpeed(value, element){
    var circle = document.querySelector(element);
    var radius = circle.r.baseVal.value;
    var circumference = radius * 2 * Math.PI;
    var html = $(element).parent().parent().find('span');
    $(".kmh").text(value.speedUnit);
    var percent = value.speed * 100 / 220;

    circle.style.strokeDasharray = `${circumference} ${circumference}`;
    circle.style.strokeDashoffset = `${circumference}`;

    const offset = circumference - ((-percent*73)/100) / 100 * circumference;
    circle.style.strokeDashoffset = -offset;

    html.text(value.speed);
  }
});
