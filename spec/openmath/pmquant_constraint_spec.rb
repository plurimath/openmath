# frozen_string_literal: true

require "spec_helper"

# The pmquant constraint symbols: PM 1012's constraint evaluation, its
# two decision rules, the signed residual and the applicability guard.
RSpec.describe "the pmquant constraint symbols" do
  let(:pmquant_ocd) { File.expand_path("../../data/pmquant.ocd", __dir__) }
  let(:pmquant_sts) { File.expand_path("../../data/pmquant.sts", __dir__) }
  let(:signatures) { Openmath::CD::Signatures.load(pmquant_sts) }
  let(:symbols) { %w[upper_limit lower_limit simple_acceptance guarded_acceptance constraint] }

  def om(body)
    %(<OMOBJ xmlns="http://www.openmath.org/OpenMath">#{body}</OMOBJ>)
  end

  def app(*parts) = "<OMA>#{parts.join}</OMA>"
  def oms(dict, name) = %(<OMS cd="#{dict}" name="#{name}"/>)
  def omi(value) = "<OMI>#{value}</OMI>"
  def rat(num, den) = app(oms("nums1", "rational"), omi(num), omi(den))
  def ustd(value, magnitude) = app(oms("pmquant", "ustd"), value, magnitude)
  def upper(boundary) = app(oms("pmquant", "upper_limit"), boundary)
  def lower(boundary) = app(oms("pmquant", "lower_limit"), boundary)
  def simple = app(oms("pmquant", "simple_acceptance"))
  def guarded(factor) = app(oms("pmquant", "guarded_acceptance"), factor)

  def constraint(*args, **options)
    Openmath.evaluate(om(app(oms("pmquant", "constraint"), *args)), **options)
  end

  describe "the CD and its signatures" do
    it "defines every constraint symbol in a schema-valid CD" do
      cd = Openmath::CD::Collection.new.load(pmquant_ocd)["pmquant"]

      expect(Openmath::CD::Collection.validate(File.read(pmquant_ocd))).to be_empty
      symbols.each do |name|
        expect(cd.definition_for(name)).to be_a(Openmath::CD::Definition)
      end
    end

    it "signs and binds every constraint symbol" do
      table = Openmath::Evaluation::BindingTable.default

      symbols.each do |name|
        expect(signatures.lookup("pmquant", name)).to be_a(Openmath::V2::Omobj)
        expect(table.lookup("pmquant", name)).not_to be_nil
      end
    end

    it "evaluates under its own signatures" do
      result = constraint(upper(omi(100)), omi(99), simple,
                          signatures: signatures)

      expect(result.verdict).to eq("satisfied")
    end
  end

  describe "simple acceptance" do
    it "satisfies an upper limit at the boundary, exactly" do
      result = constraint(upper(omi(100)), omi(100), simple)

      expect(result.verdict).to eq("satisfied")
      expect(result.residual).to eq(0)
      expect(result.rule.name).to eq("simple-acceptance")
      expect(result.band).to be_nil
    end

    it "does not satisfy an upper limit above the boundary" do
      result = constraint(upper(omi(100)), rat(1001, 10), simple)

      expect(result.verdict).to eq("not-satisfied")
      expect(result.residual).to eq(Rational(1, 10))
    end

    it "carries the clause 7 residual for a lower limit" do
      # L >= 10,00 kOhm against 10,02 kOhm: satisfied, residual +0,02.
      result = constraint(lower(rat(1000, 100)), rat(1002, 100), simple)

      expect(result.verdict).to eq("satisfied")
      expect(result.residual).to eq(Rational(1, 50))
    end

    it "does not satisfy a lower limit below the boundary" do
      result = constraint(lower(omi(10)), omi(9), simple)

      expect(result.verdict).to eq("not-satisfied")
      expect(result.residual).to eq(-1)
    end

    it "compares the reported value of an uncertain result" do
      result = constraint(upper(omi(100)), ustd(rat(1001, 10), rat(1, 2)), simple)

      expect(result.verdict).to eq("not-satisfied")
    end
  end

  describe "guarded acceptance" do
    it "is conditional inside the band (clause 6 first example)" do
      # L <= 100,0 V against 99,7 V +- 0,5 V, k = 2.
      result = constraint(upper(omi(100)), ustd(rat(997, 10), rat(1, 2)),
                          guarded(omi(2)))

      expect(result.verdict).to eq("conditional")
      expect(result.band).to eq(1)
      expect(result.zone).to eq([99, 100])
      expect(result.residual.value).to eq(Rational(-3, 10))
      expect(result.residual.magnitude).to eq(1)
      expect(result.residual.coverage_factor).to eq(2)
      expect(result.rule.coverage_factor).to eq(2)
    end

    it "is conditional at the band's edge (clause 6 second example)" do
      result = constraint(upper(omi(100)), ustd(omi(99), rat(1, 2)),
                          guarded(omi(2)))

      expect(result.verdict).to eq("conditional")
      expect(result.residual.value).to eq(-1)
    end

    it "is conditional at the limit itself" do
      result = constraint(upper(omi(100)), ustd(omi(100), rat(1, 2)),
                          guarded(omi(2)))

      expect(result.verdict).to eq("conditional")
    end

    it "is satisfied below the band" do
      result = constraint(upper(omi(100)), ustd(rat(989, 10), rat(1, 2)),
                          guarded(omi(2)))

      expect(result.verdict).to eq("satisfied")
    end

    it "is not satisfied above the limit" do
      result = constraint(upper(omi(100)), ustd(rat(1001, 10), rat(1, 2)),
                          guarded(omi(2)))

      expect(result.verdict).to eq("not-satisfied")
    end

    it "mirrors the zone for a lower limit" do
      inside = constraint(lower(omi(10)), ustd(rat(103, 10), rat(1, 5)),
                          guarded(omi(2)))
      above = constraint(lower(omi(10)), ustd(rat(105, 10), rat(1, 5)),
                         guarded(omi(2)))
      below = constraint(lower(omi(10)), ustd(rat(99, 10), rat(1, 5)),
                         guarded(omi(2)))

      expect(inside.zone).to eq([10, Rational(52, 5)])
      expect(inside.verdict).to eq("conditional")
      expect(above.verdict).to eq("satisfied")
      expect(below.verdict).to eq("not-satisfied")
    end

    it "refuses results without a standard uncertainty" do
      expect do
        constraint(upper(omi(100)), omi(99), guarded(omi(2)))
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /guarded acceptance/)
      expect do
        constraint(upper(omi(100)),
                   app(oms("pmquant", "uexp"), omi(99), omi(1), omi(2)),
                   guarded(omi(2)))
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /guarded acceptance/)
    end

    it "refuses a coverage factor that is not positive" do
      expect do
        Openmath.evaluate(om(guarded(omi(0))))
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /coverage factor/)
    end
  end

  describe "the applicability guard" do
    it "applies the constraint when the guard holds" do
      result = constraint(upper(omi(100)), omi(101), simple,
                          app(oms("relation1", "eq"), omi(1), omi(1)))

      expect(result.applicable).to be(true)
      expect(result.verdict).to eq("not-satisfied")
    end

    it "records the constraint as inapplicable when the guard is false" do
      result = constraint(upper(omi(100)), omi(101), simple,
                          app(oms("relation1", "eq"), omi(1), omi(2)))

      expect(result.applicable).to be(false)
      expect(result.verdict).to be_nil
      expect(result.diagnostics).to eq(["inapplicable: the applicability guard is false"])
    end

    it "refuses a guard that is not a boolean" do
      expect do
        constraint(upper(omi(100)), omi(1), simple, omi(1))
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /applicability guard/)
    end
  end

  describe "the refusals" do
    it "refuses operands in the wrong places" do
      expect do
        constraint(omi(100), omi(1), simple)
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /constraint limit/)
      expect do
        constraint(upper(omi(100)), omi(1), omi(2))
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /decision rule/)
      expect do
        constraint(upper(omi(100)), "<OMSTR>x</OMSTR>", simple)
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /constraint result/)
      expect do
        Openmath.evaluate(om(upper("<OMSTR>x</OMSTR>")))
      end.to raise_error(Openmath::Evaluation::OperandTypeError, /limit/)
    end

    it "refuses the wrong arity" do
      expect do
        constraint(upper(omi(100)), omi(1))
      end.to raise_error(Openmath::Evaluation::ArityError)
    end
  end
end
