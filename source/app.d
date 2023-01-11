import std.stdio;
import std.string : chop;
import std.algorithm;
import std.random;
import std.conv;

void main()
{
	
	writeln("> How many Humans are playing?");
	int players = chop(readln()).to!int;
	writeln("> What are our left- and rightmost card?");
	Card[4] ourCards = [parseToCard(readln()), Card.UNKNOWN, Card.UNKNOWN, parseToCard(readln())];
	writeln("> Who goes first?");
	int turn = chop(readln()).to!int;
	writeln(turn);
	writeln("> What's the starting card?");
	auto top = parseToCard(readln());

	auto b = new Bot(players+1, ourCards, turn, top);

	while (!b.finalRound) {
		if (b.getTurn() == 0) {
			b.doTurn();	
		} else {
			writeln("> Next turn - what card is on top of the stack?");
			b.waitTurn(parseToCard(readln()));
		}
		b.printCards();
	}

	b.printCards();
}

enum Card {
	ZERO,
	ONE,
	TWO,
	THREE,
	FOUR,
	FIVE,
	SIX,
	SEVEN,
	EIGHT,
	UNKNOWN,
	NINE,
	LOOK,
	DRAW,
	SWAP
}

class Bot {
	Card[][4] cards; // keeps track of all cards that the bot knows.
	Card      topOfStack;

	public bool finalRound = false;
	int finalTurn = -1;
	int playerCount;
	int turn; // 0 is bot, 1 is player 1, 2 is player 2 etc

	// --

	this(int players, Card[4] ownCards, int turn, Card topOfStack) {
		if (turn+1 > players) throw new Exception("turn idx greater than amount of players");

		for (int i = 0; i < players; i++) {
			this.cards[i] = [Card.UNKNOWN, Card.UNKNOWN, Card.UNKNOWN, Card.UNKNOWN];
		}

		this.playerCount = players;
		this.cards[0]    = ownCards;
		this.turn        = turn;
		this.topOfStack  = topOfStack;
	}

	public int getTurn() { return this.turn; }
	public void nextTurn() {
		if (turn+1 == playerCount) this.turn = 0;
		else if (turn == finalTurn) finalRound = true;
		else this.turn++; 
	}

	public void printCards() {
		writefln("my cards were: %s, %s, %s, %s", cards[0][0], cards[0][1], cards[0][2], cards[0][3]);
	}

	public void waitTurn(Card newTop) {

		writeln("> Did someone take the top of the stack?");

		if (readln().length > 1) {
			writeln("> Who took it?");
			int player = chop(readln()).to!int;
			writeln("> Where did they put it?");
			int card = chop(readln()).to!int;
			this.cards[player][card-1] = this.topOfStack;
			writeln("! Noted");
			this.topOfStack = newTop;
			nextTurn();
			return;
		}

		this.topOfStack = newTop;
		if (newTop == Card.SWAP) {
			writeln("> Were cards swapped?");
			if (readln().length < 1) goto end; // no swap, just a disposal

			writeln("> Which cards were swapped?");
			writeln("    e.g. 1,2 means player one, card two");

			writeln("> Card one:");
			string swapOne = readln();
			writeln("> Card two:");
			string swapTwo = readln();

			int player1 = swapOne[0].to!int - 48;
			int card1 = swapOne[2].to!int - 48;

			int player2 = swapTwo[0].to!int - 48;
			int card2 = swapTwo[2].to!int - 48;
			writefln("> So: %d,%d %d,%d", player1, card1, player2, card2);
			waitSwapTurn(player1, card1, player2, card2);
		}

		end:

		writeln("> Is the round ending?");
		if (readln().length > 1) {
			this.finalTurn = this.turn - 1;
		}

		nextTurn();
	}

	// keep track of what card gets swapped
	public void waitSwapTurn(int player, int card, int player2, int card2) {
		Card swappedCard = this.cards[player][card];
		this.cards[player][card] = this.cards[player2][card2];
		this.cards[player2][card2] = swappedCard;
	}

	public void doTurn() {
		// look at the top of the stack
		if (this.topOfStack < Card.SIX) {
			if (this.topOfStack == Card.FIVE) {
				int highest = findHighestCard();
				if (this.cards[0][highest] <= Card.FIVE) {
					goto draw; // we just draw a card.
				} else {
					disposeCard(highest, this.topOfStack);
				}
			} else {
				writeln("Low card. Who messed up their gamba?");
				// find the highest card and dispose of it.
				int highest = findHighestCard();
				disposeCard(highest, this.topOfStack);
			}

			nextTurn();
			return;
		}

		draw:
		// draw a card
		Card card = drawCard();
		decideOnAction(card);

		if (sumCards() < 16) {
			this.finalTurn = this.playerCount-1;
			writeln("! Final round.");
		}

		nextTurn();
	}

	private int sumCards() {
		return cast(int)(cards[0][0] + cards[0][1] + cards[0][2] + cards[0][3]);
	}

	private Card drawCard() {
		// ask for REPL input and parse it
		writeln("> What is the card that has been drawn?");
		return parseToCard(readln());
	}

	private void decideOnAction(Card card) {
		switch (card) {
			case Card.ZERO: .. case Card.FOUR:
				writeln("Low card, nice.");
				// find the highest card and dispose of it.
				int highest = findHighestCard();
				disposeCard(highest, card);
				break;
			case Card.FIVE:
				writeln("Hmm...");
				// taking this card depends on how good the rest of our cards are.
				int highest = findHighestCard();
				if (this.cards[0][highest] <= Card.FIVE) {
					this.topOfStack = card;
				} else {
					disposeCard(highest, card);
				}
				break;
			case Card.SIX: .. case Card.NINE:
				writeln("! No good, put that back.");
				this.topOfStack = card;
				break;
			case Card.LOOK:
				writeln("This might be good!");
				int unknown = searchUnknown();
				if (unknown == -1) break;

				writefln("> What is card %d?", unknown+1);
				this.cards[0][unknown] = parseToCard(readln());
				break;
			case Card.DRAW:
				immutable(Card[]) copycat = this.cards[0].idup();
				
				decideOnAction(drawCard());
				// if a player has not decided to take that card, we can draw again
				if (!this.cards[0].equal(copycat)) break;

				decideOnAction(drawCard());
				break;
			case Card.SWAP:
				writeln("Let's get this hehehehaw on the road.");
				int[] lowest = findLowestOpponentCard();
				int highest = findHighestCard();

				Card toSwap = this.cards[0][highest];

				this.cards[0][highest] = cards[lowest[0]][lowest[1]];
				cards[lowest[0]][lowest[1]] = toSwap;

				writefln("! Swap card %d of player %d with card %d", lowest[1]+1, lowest[0], highest);
				break;
			default:
				break;
		}
	}

	// TODO: weight this differently, we might be giving our opponents good cards.
	private int findHighestCard() {
		Card highest = Card.ZERO; // start low
		int idx = 0;
		for (int i = 0; i < 4; i++) {
			if (this.cards[0][i] > highest) {
				highest = this.cards[0][i];
				idx = i;
			}
		}
		return idx;
	}

	private int searchUnknown() {
		for (int i = 0; i < 4; i++) {
			if (this.cards[0][i] == Card.UNKNOWN) {
				return i;
			}
		}
		return -1;
	}

	private void disposeCard(int which, Card replacement) {
		writefln("! Replace card %d", which+1);
		if (cards[0][which] == Card.UNKNOWN) {
			writeln("> What did that card end up being?");
			this.topOfStack = parseToCard(readln());
		}
		this.topOfStack = this.cards[0][which];
		this.cards[0][which] = replacement;
	}

	private int[] findLowestOpponentCard() {
		Card lowest = Card.UNKNOWN; // start high
		int card   = 0;
		int player = 1; 
		// don't search ourselves
		for (int j = 1; j < this.playerCount; j++) {
			for (int i = 0; i < 4; i++) {
				if (this.cards[j][i] <= lowest) {
					lowest = this.cards[0][i];
					card = i;
					player = j;
				}
			}
		}

		// if still unknown, pick at random
		if (lowest == Card.UNKNOWN) {
			auto a = uniform(1, this.playerCount);
			writefln("thing: %d", a);
			player = a;
			card = uniform(0, 3);
		}
		return [player, card];
	}
}

public Card parseToCard(string input) {
	final switch (chop(input)) {
		case "0": return Card.ZERO;
		case "1": return Card.ONE;
		case "2": return Card.TWO;
		case "3": return Card.THREE;
		case "4": return Card.FOUR;
		case "5": return Card.FIVE;
		case "6": return Card.SIX;
		case "7": return Card.SEVEN;
		case "8": return Card.EIGHT;
		case "9": return Card.NINE;
		case "S", "s": return Card.SWAP;
		case "L", "l": return Card.LOOK;
		case "D", "d": return Card.DRAW;
	}
}