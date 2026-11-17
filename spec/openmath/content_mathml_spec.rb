# frozen_string_literal: true

require "spec_helper"

# The Content MathML v4 encoding (the plurimath#35 re-parenting):
# Content MathML rides the openmath gem's content models — csymbol ↔
# OpenMath symbol, apply ↔ OMA, lambda/bvar ↔ the binding containers —
# so Content MathML expressions parse, evaluate and round-trip through
# the same semantic layer as the XML and binary encodings.
RSpec.describe Openmath::ContentMathML do
  def parse(markup)
    described_class.parse(markup)
  end

  def generate(object_or_xml)
    described_class.generate(object_or_xml)
  end

  def body(markup)
    markup.delete_prefix('<math xmlns="http://www.w3.org/1998/Math/MathML">')
      .delete_suffix("</math>")
  end

  it "parses the strict core: csymbol, apply, ci, cn, cs" do
    object = parse(
      '<math xmlns="http://www.w3.org/1998/Math/MathML">' \
      '<apply><csymbol cd="arith1" name="plus"/><ci>x</ci><cn>1</cn></apply>' \
      "</math>",
    )

    application = object.oma_value.first
    expect(application.oms_value.first.cd).to eq("arith1")
    expect(application.oms_value.first.name).to eq("plus")
    expect(application.omv_value.first.name).to eq("x")
    expect(application.omi_value.first.value.first).to eq("1")
  end

  it "parses cd-less csymbols typed" do
    expect do
      parse('<math xmlns="http://www.w3.org/1998/Math/MathML"><csymbol name="f"/></math>')
    end.to raise_error(Openmath::ContentMathML::Error, /cd and name/)
  end

  it "transforms the non-strict operator elements through the operator table" do
    object = parse(
      '<math xmlns="http://www.w3.org/1998/Math/MathML">' \
      "<apply><plus/><cn>1</cn><cn>2</cn></apply></math>",
    )

    application = object.oma_value.first
    expect(application.oms_value.first.cd).to eq("arith1")
    expect(application.oms_value.first.name).to eq("plus")
    expect(application.omi_value.map { |i| i.value.first }).to eq(%w[1 2])
  end

  it "transforms the container form: operator element and arguments side by side" do
    object = parse(
      '<math xmlns="http://www.w3.org/1998/Math/MathML">' \
      "<plus/><ci>x</ci><cn>2</cn></math>",
    )

    application = object.oma_value.first
    expect(application.oms_value.first.name).to eq("plus")
    expect(application.omv_value.first.name).to eq("x")
    expect(application.omi_value.first.value.first).to eq("2")
  end

  it "maps lambda and bvar to the fns1/lambda binding" do
    object = parse(
      '<math xmlns="http://www.w3.org/1998/Math/MathML">' \
      "<lambda><bvar><ci>x</ci></bvar>" \
      "<apply><plus/><ci>x</ci><cn>1</cn></apply></lambda></math>",
    )

    binder = object.ombind_value.first
    expect(binder.oms_value.first.cd).to eq("fns1")
    expect(binder.oms_value.first.name).to eq("lambda")
    expect(binder.ombvar_value.first.omv_value.first.name).to eq("x")
    expect(binder.oma_value.first.oms_value.first.name).to eq("plus")
  end

  it "parses cn rationals and e-notation through the exact constructions" do
    rational = parse('<math xmlns="http://www.w3.org/1998/Math/MathML">' \
                     '<cn type="rational">1<sep/>4</cn></math>').oma_value.first
    expect(rational.oms_value.first.name).to eq("rational")
    expect(rational.omi_value.first.value.first).to eq("1")
    expect(rational.omi_value.last.value.first).to eq("4")

    base = parse('<math xmlns="http://www.w3.org/1998/Math/MathML">' \
                 '<cn base="16">1af</cn></math>').oma_value.first
    expect(base.oms_value.first.name).to eq("based_integer")
    expect(base.omstr_value.first.value.first).to eq("1af")

    e_notation = parse('<math xmlns="http://www.w3.org/1998/Math/MathML">' \
                       '<cn type="e-notation">1<sep/>3</cn></math>').oma_value.first
    expect(e_notation.oms_value.first.name).to eq("times")
    expect(e_notation.oma_value.last.oms_value.first.name).to eq("power")
  end

  it "refuses cn types with no exact OpenMath form" do
    expect do
      parse('<math xmlns="http://www.w3.org/1998/Math/MathML">' \
            '<cn type="double">1.5</cn></math>')
    end.to raise_error(Openmath::ContentMathML::Error, /no exact OpenMath form/)
  end

  it "refuses presentation elements and other markup outside the core" do
    expect do
      parse('<math xmlns="http://www.w3.org/1998/Math/MathML"><mi>x</mi></math>')
    end.to raise_error(Openmath::ContentMathML::Error, /outside the strict semantic core/)
  end

  it "generates the strict form" do
    xml = '<OMOBJ xmlns="http://www.openmath.org/OpenMath">' \
          '<OMA><OMS cd="arith1" name="plus"/><OMV name="x"/><OMI>1</OMI></OMA>' \
          "</OMOBJ>"
    markup = generate(xml)

    expect(markup).to include('<csymbol cd="arith1" name="plus"/>')
    expect(markup).to include("<ci>x</ci>")
    expect(markup).to include("<cn>1</cn>")
    expect(markup).not_to include("OMA")
  end

  it "generates lambda and bvar" do
    xml = '<OMOBJ xmlns="http://www.openmath.org/OpenMath">' \
          "<OMBIND><OMS cd=\"fns1\" name=\"lambda\"/>" \
          "<OMBVAR><OMV name=\"x\"/></OMBVAR>" \
          '<OMA><OMS cd="arith1" name="plus"/><OMV name="x"/><OMI>1</OMI></OMA>' \
          "</OMBIND></OMOBJ>"

    expect(generate(xml)).to include("<lambda>").and include("<bvar>")
  end

  it "refuses constructs with no Content MathML form" do
    expect do
      generate('<OMOBJ xmlns="http://www.openmath.org/OpenMath"><OMB>aGk=</OMB></OMOBJ>')
    end.to raise_error(Openmath::ContentMathML::Error, /OMB has no Content MathML form/)
  end

  it "round-trips stably through parse and generation" do
    markup = '<math xmlns="http://www.w3.org/1998/Math/MathML">' \
             '<apply><csymbol cd="arith1" name="plus"/><ci>x</ci><cn>1</cn></apply>' \
             "</math>"
    once = generate(parse(markup))
    twice = generate(parse(once))

    expect(twice).to eq(once)
  end

  it "evaluates parsed Content MathML under the CD binding table" do
    object = parse('<math xmlns="http://www.w3.org/1998/Math/MathML">' \
                   '<apply><plus/><cn>1</cn><cn>2</cn></apply></math>')

    expect(Openmath.evaluate(object)).to eq(3)
  end
end
