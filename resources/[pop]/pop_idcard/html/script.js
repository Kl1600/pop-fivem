$(document).ready(function(){
    window.addEventListener("message", function(event) {
        if (event.data.action == "show") {
            const d = event.data.data;
            const isMx = (d.cardType === 'mx');

            // Remplir les champs US
            $("#us-lastname").text(d.lastname);
            $("#us-firstname").text(d.firstname);
            $("#us-sex").text(d.sex);
            $("#us-nationality").text(d.nationality);

            // Remplir les champs MX
            $("#mx-lastname").text(d.lastname);
            $("#mx-firstname").text(d.firstname);
            $("#mx-sex").text(d.sex);
            $("#mx-nationality").text(d.nationality);

            // Photo
            // Pas de photo du titulaire : on masque l'image, le fond gris par défaut reste visible
            var photoSrc = d.headshot ? "https://nui-img/" + d.headshot + "/" + d.headshot : "";
            var photoVis = photoSrc ? "visible" : "hidden";
            $("#player-photo-us").attr("src", photoSrc).css("visibility", photoVis);
            $("#player-photo-mx").attr("src", photoSrc).css("visibility", photoVis);

            // Basculer entre US et MX
            if (isMx) {
                $(".card").addClass("show-mx");
            } else {
                $(".card").removeClass("show-mx");
            }

            $("#idcard-container").fadeIn(300);

        } else if (event.data.action == "hide") {
            $("#idcard-container").fadeOut(150);
        }
    });

    $(document).on("keyup", function(e) {
        if (e.keyCode == 27 || e.keyCode == 13) {
            $("#idcard-container").fadeOut(150);
            $.post("https://pop_idcard/close", JSON.stringify({}));
        }
    });
});
