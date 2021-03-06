function draw_bar(element, segments) {
	var height = element.height(), width = element.width();
	var paper = Raphael(element[0], width, height);

	sum = 0;
	for (var i = 0; i < segments.length; i++) {
		sum += segments[i].count;
	}
	x = count = 0;
	for (var i in segments) {
		s = segments[i];
		count += s.count;
		x_end = Math.round(count * width / sum);
		rect = paper.rect(x, 0, x_end, height);
		if ('color' in s) {
			rect.attr("fill", s.color);
			rect.attr("stroke", s.color);
		}
		x = x_end;
	}
}

function party_sort(mp_a, mp_b) {
	if (mp_a.party == mp_b.party) {
		if (mp_a.name > mp_b.name)
			return 1;
		else
			return -1;
	}
	if (mp_a.party > mp_b.party)
		return 1;
	else if (mp_a.party < mp_b.party)
		return -1;
	else
		return 0;
}

function create_mp_entry(mp) {
	var row = document.createElement("tr");
	var cols = []
	var party = party_dict[mp.party];
	var html = "<td><img class='party_logo' src='" + party.logo + "' /\></td>";
	html += "<td><img class='portrait' src='" + mp.portrait + "' /\></td>";
	html += "<td class='name'><a href='" + mp.url + "'>" + mp.name + "</a></td>"
	if ('answer' in mp) {
		color = option_dict[mp.answer].color;
		if (color) {
			html += "<td class='answer' style='color: " + color + ";'>";
			html += "&#x25cf;";
			html += "</td>"
		} else {
			html += "<td></td>";
		}
	} else {
		html += "<td></td>";
	}
	$(row).append(html);

	var answer_el = $(".answer", row)
	answer_el.mouseover(function() {
		var url = "/opinions/yle2011/0/" + mp.id + "/";

		if ('answer_fetched' in this)
			return;
		
		$.ajax({
			url: url,
			dataType: 'json',
			context: this,
			success: function(json) {
				this.answer_fetched = true;
				if (!('explanation' in json))
					return;
				$(this).tooltip({
					delay: 200,
					fade: 200,
					bodyHandler: function() {
						s = "<h3>" + mp.name + "</h3>";
						s += "<p>" + json.explanation + "</p>";
						return s;
					}
				});
				$(this).delay(0).mouseenter();
			}
		});
	});
	
	return row;
}

function count_stats() {
	function process_mp(mp) {
		var party = party_dict[mp.party];
		var opt_cong;

		if ('answer' in mp) {
			if (!('answer_counts' in party)) {
				party.answer_counts = [];
			}
			var ac = party.answer_counts;
			if (!(mp.answer in ac)) {
				ac[mp.answer] = 1;
			} else {
				ac[mp.answer]++;
			}
			counts = total_counts['opts'];
			if (!(mp.answer in counts)) {
				counts[mp.answer] = 1;
			} else {
				counts[mp.answer]++;
			}
			var opt = option_dict[mp.answer];
			opt_cong = opt.congruence;
		}
		if ('vote' in mp) {
			if (!('vote_counts' in party)) {
				party.vote_counts = [];
			}
			var vc = party.vote_counts;
			if (!(mp.vote in vc)) {
				vc[mp.vote] = 1;
			} else {
				vc[mp.vote]++;
			}
			counts = total_counts['votes'];
			if (!(mp.vote in counts)) {
				counts[mp.vote] = 1;
			} else {
				counts[mp.vote]++;
			}
		}

		if (!('vote' in mp && 'answer' in mp)) {
			return;
		}
		if (!('cong_counts' in party)) {
			party.cong_counts = [];
		}
		var cong = 0;
		if (mp.vote == 'Y') {
			if (opt_cong > 0) {
				cong = 1;
			} else if (opt_cong < 0) {
				cong = -1;
			}
		} else if (mp.vote == 'N') {
			if (opt_cong > 0) {
				cong = -1;
			} else if (opt_cong < 0) {
				cong = 1;
			}
		}
		var cc = party.cong_counts;

		if (!(cong in cc)) {
			cc[cong] = 1;
		} else {
			cc[cong]++;
		}
		counts = total_counts['cong'];
		if (!(cong in counts)) {
			counts[cong] = 1;
		} else {
			counts[cong]++;
		}
	}

	for (var i in mp_list) {
		process_mp(mp_list[i]);
	}
}

