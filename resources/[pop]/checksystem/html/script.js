let currentItemId = null;

window.addEventListener("message", function(event){

    const data = event.data;

    if(data.action === "open"){

        document.getElementById("container").style.display = "flex";

        if(data.dataUser && data.dataUser.fullName){
            document.getElementById("signature").value = data.dataUser.fullName;
        }

        currentItemId = data.itemId || null;

        const banner = document.getElementById("companyBanner");
        if(data.companyLabel){
            document.getElementById("companyLabel").textContent = data.companyLabel;
            banner.style.display = "block";
        } else {
            banner.style.display = "none";
        }
    }

    if(data.action === "close"){
        document.getElementById("container").style.display = "none";
    }
});

document.getElementById("closeBtn").addEventListener("click", function(){

    fetch(`https://${GetParentResourceName()}/close`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        }
    });

});

document.getElementById("validateBtn").addEventListener("click", function(){

    const cheque = {
        beneficiaire: document.getElementById("beneficiaire").value,
        montant: document.getElementById("montant").value,
        montantLettres: document.getElementById("montantLettres").value,
        motif: document.getElementById("motif").value,
        signature: document.getElementById("signature").value,
        date: document.getElementById("date").value,
        itemId: currentItemId
    };

    fetch(`https://${GetParentResourceName()}/validateCheque`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify(cheque)
    });

});

document.addEventListener("keyup", function(event){

    if(event.key === "Escape"){

        fetch(`https://${GetParentResourceName()}/close`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            }
        });

    }
});
